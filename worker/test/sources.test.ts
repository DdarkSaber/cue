import { afterEach, describe, expect, it, vi } from "vitest";

import { normalizeCinemeta } from "../src/catalog/cinemeta";
import { fitsKind } from "../src/catalog/tvmaze";
import { isAllowedImageUrl } from "../src/schemas";
import { call, emptyUpstream, fakeEnv, fakeKv, mockUpstream, postJson } from "./helpers";

afterEach(() => vi.restoreAllMocks());

const show = (over: Record<string, unknown> = {}) => ({
  id: 1,
  name: "Synthetic Drama",
  type: "Scripted",
  language: "Korean",
  genres: ["Drama", "Romance"],
  weight: 80,
  premiered: "2026-05-01",
  image: { original: "https://static.tvmaze.com/uploads/a.jpg" },
  network: { country: { code: "KR" } },
  ...over,
});

describe("which TVmaze shows count as dramas and series", () => {
  it("keeps popular scripted shows with art, by country", () => {
    expect(fitsKind(show(), "kdrama")).toBe(true);
    expect(fitsKind(show({ network: { country: { code: "CN" } }, language: "Chinese" }), "cdrama")).toBe(true);
    expect(fitsKind(show({ network: { country: { code: "JP" } }, language: "Japanese" }), "jdrama")).toBe(true);
    expect(fitsKind(show({ network: { country: { code: "US" } }, language: "English" }), "series")).toBe(true);
  });

  it("drops anime, unscripted, art-less, obscure and wrong-country shows", () => {
    expect(fitsKind(show({ genres: ["Anime"] }), "kdrama")).toBe(false);
    expect(fitsKind(show({ type: "Reality" }), "kdrama")).toBe(false);
    expect(fitsKind(show({ image: null }), "kdrama")).toBe(false);
    expect(fitsKind(show({ weight: 10 }), "kdrama")).toBe(false);
    expect(fitsKind(show(), "jdrama")).toBe(false);
    // A Korean show is never an "English series".
    expect(fitsKind(show({ language: "English" }), "series")).toBe(false);
  });

  it("uses language when a streaming show has no country", () => {
    expect(fitsKind(show({ network: null, webChannel: null }), "kdrama")).toBe(true);
  });
});

describe("Cinemeta normalisation", () => {
  const movie = {
    id: "tt6751668",
    imdb_id: "tt6751668",
    name: "Synthetic Film",
    year: "2019",
    country: "South Korea, Japan",
    genres: ["Drama", "Thriller"],
    imdbRating: "8.5",
    poster: "https://images.metahub.space/poster/small/tt6751668/img",
    background: "https://images.metahub.space/background/medium/tt6751668/img",
    description: "A synthetic story.",
  };

  it("maps a film with a sharper poster, a country code and a 0-100 score", () => {
    expect(normalizeCinemeta(movie, "movie")).toMatchObject({
      provider: "cinemeta",
      providerId: "tt6751668",
      providerKind: "movie",
      kind: "movie",
      year: 2019,
      country: "KR",
      score: 85,
      status: "finished",
      adult: false,
      posterUrl: "https://images.metahub.space/poster/medium/tt6751668/img",
    });
  });

  it("reads series seasons and status, and a damaged year range", () => {
    const item = normalizeCinemeta(
      {
        ...movie,
        year: "2019–",
        status: "Continuing",
        videos: [{ season: 1 }, { season: 1 }, { season: 2 }, { season: 0 }],
      },
      "series",
    );
    // The sample is Korean, so it is a K-drama.
    expect(item.kind).toBe("kdrama");
    expect(normalizeCinemeta({ ...movie, country: "United States" }, "series").kind).toBe("series");
    expect(item.year).toBe(2019);
    expect(item.status).toBe("airing");
    expect(item.seasons).toEqual([
      { number: 1, episodes: 2, year: null },
      { number: 2, episodes: 1, year: null },
    ]);
  });

  it("unknown scores stay unknown", () => {
    expect(normalizeCinemeta({ ...movie, imdbRating: undefined }, "movie").score).toBeNull();
  });
});

describe("key-free routes", () => {
  it("discovers movies from Cinemeta with a mood genre and paging", async () => {
    const calls = mockUpstream(vi, (url) =>
      url.hostname === "cinemeta-catalogs.strem.io"
        ? Response.json({
            metas: [
              {
                id: "tt1",
                imdb_id: "tt1",
                name: "Film",
                poster: "https://images.metahub.space/poster/small/tt1/img",
                genres: ["Action"],
              },
              { id: "tt2", name: "No poster" },
            ],
          })
        : emptyUpstream(url),
    );
    const res = await call("/catalog/discover?kind=movie&mood=hype&page=3");
    expect(res.status).toBe(200);
    const body = (await res.json()) as { items: { providerId: string }[]; hasNext: boolean };
    expect(body.items.map((i) => i.providerId)).toEqual(["tt1"]);
    expect(calls[0]!.url.pathname).toBe("/top/catalog/movie/top/genre=Action&skip=100.json");
  });

  it("discovers K-dramas from TVmaze, newest pages first, and remembers the last page", async () => {
    const kv = fakeKv();
    const calls = mockUpstream(vi, (url) => {
      if (url.hostname !== "api.tvmaze.com") return emptyUpstream(url);
      const page = Number(url.searchParams.get("page"));
      if (page > 10) return new Response(null, { status: 404 });
      return Response.json(
        page === 10
          ? [show({ id: 7, weight: 90 }), show({ id: 8, weight: 50 }), show({ id: 9, type: "Reality" })]
          : [],
      );
    });
    const env = fakeEnv({ CATALOG_CACHE: kv });
    const res = await call("/catalog/discover?kind=kdrama", {}, env);
    const body = (await res.json()) as { items: { providerId: string; kind: string }[] };
    expect(body.items.map((i) => i.providerId)).toEqual(["7", "8"]);
    expect(body.items.every((i) => i.kind === "kdrama")).toBe(true);
    expect(kv.store.get("v1:tvmaze:last")).toBe("10");
    expect(calls.some((c) => c.url.searchParams.get("page") === "10")).toBe(true);
  });

  it("title lookups accept IMDb ids", async () => {
    mockUpstream(vi, (url) =>
      url.hostname === "v3-cinemeta.strem.io"
        ? Response.json({
            meta: {
              id: "tt6751668",
              imdb_id: "tt6751668",
              name: "Film",
              poster: "https://images.metahub.space/poster/small/tt6751668/img",
            },
          })
        : emptyUpstream(url),
    );
    const ok = await call("/catalog/title/cinemeta/tt6751668?type=movie");
    expect(ok.status).toBe(200);
    expect(((await ok.json()) as { providerKind: string }).providerKind).toBe("movie");
    expect((await call("/catalog/title/cinemeta/..%2Fetc")).status).toBe(400);
    expect((await call("/catalog/title/cinemeta/abc")).status).toBe(400);
  });

  it("matches movies through Cinemeta and series through TVmaze without a key", async () => {
    const calls = mockUpstream(vi);
    await postJson("/catalog/match", {
      items: [
        { q: "Synthetic Film", kind: "movie" },
        { q: "Synthetic Series", kind: "series" },
      ],
    });
    const hosts = calls.map((c) => c.url.hostname);
    expect(hosts).toContain("v3-cinemeta.strem.io");
    expect(hosts).toContain("api.tvmaze.com");
  });

  it("a drama missing from TVmaze is found by its IMDb-style title and deduplicated", async () => {
    mockUpstream(vi, (url) => {
      if (url.hostname === "api.tvmaze.com") {
        return Response.json([
          { show: { id: 1, name: "Strong Girl Bong-soon", premiered: "2017-02-24", language: "Korean", genres: [] } },
        ]);
      }
      if (url.hostname === "v3-cinemeta.strem.io") {
        return Response.json({
          metas: [
            { id: "tt1", imdb_id: "tt1", name: "Strong Woman Do Bong-soon", year: "2017", country: "South Korea", poster: "https://images.metahub.space/poster/small/tt1/img" },
            { id: "tt2", imdb_id: "tt2", name: "Strong Girl Bong-soon", year: "2017" },
          ],
        });
      }
      return emptyUpstream(url);
    });
    const res = await call("/catalog/search?q=Strong%20Woman%20Do%20Bong-soon&kind=kdrama");
    const { items } = (await res.json()) as { items: { titleEn: string; provider: string; kind: string }[] };
    expect(items.map((i) => i.titleEn)).toEqual(["Strong Girl Bong-soon", "Strong Woman Do Bong-soon"]);
    expect(items[1]).toMatchObject({ provider: "cinemeta", kind: "kdrama" });
  });

  it("posters from the Cinemeta image host pass the proxy allowlist", () => {
    expect(isAllowedImageUrl("https://images.metahub.space/poster/medium/tt1/img")).toBe(true);
    expect(isAllowedImageUrl("https://images.metahub.space.evil.example/x")).toBe(false);
  });

  it("a TMDB key, when set, still takes over", async () => {
    const calls = mockUpstream(vi);
    await call("/catalog/discover?kind=movie", {}, fakeEnv({ TMDB_API_KEY: "k" }));
    expect(calls[0]!.url.hostname).toBe("api.themoviedb.org");
  });
});
