import { afterEach, describe, expect, it, vi } from "vitest";

import { normalizeTmdb } from "../src/catalog/tmdb";
import { normalizeTvmaze } from "../src/catalog/tvmaze";
import { plainText } from "../src/catalog/types";
import { call, emptyUpstream, fakeEnv, fakeKv, mockUpstream, postJson } from "./helpers";

afterEach(() => vi.restoreAllMocks());

const anilistMedia = {
  id: 101,
  idMal: 55,
  type: "MANGA",
  format: "MANGA",
  status: "RELEASING",
  episodes: null,
  chapters: null,
  countryOfOrigin: "KR",
  isAdult: false,
  averageScore: 84,
  genres: ["Action", "Fantasy"],
  startDate: { year: 2018 },
  title: { romaji: "Sample Romaji", english: "Sample", native: "샘플" },
  coverImage: { extraLarge: "https://s4.anilist.co/file/x.jpg", large: null },
  bannerImage: null,
  description: "A <i>synthetic</i> story.<br>Second line &amp; more.",
  tags: [
    { name: "Tower", rank: 90, isAdult: false, isMediaSpoiler: false },
    { name: "Twist", rank: 95, isAdult: false, isMediaSpoiler: true },
    { name: "Minor", rank: 20, isAdult: false, isMediaSpoiler: false },
  ],
};

describe("TMDB and TVmaze normalisation", () => {
  it("maps a Korean TV row to kdrama with a 0-100 score", () => {
    const item = normalizeTmdb(
      {
        id: 9,
        name: "Sample Drama",
        original_name: "샘플 드라마",
        first_air_date: "2021-03-01",
        origin_country: ["KR"],
        genre_ids: [18, 9648],
        vote_average: 8.4,
        vote_count: 120,
        poster_path: "/p.jpg",
        overview: "Synthetic.",
      },
      "tv",
    );
    expect(item).toMatchObject({
      kind: "kdrama",
      providerKind: "tv",
      titleNative: "샘플 드라마",
      year: 2021,
      score: 84,
      genres: ["Drama", "Mystery"],
      posterUrl: "https://image.tmdb.org/t/p/w500/p.jpg",
      episodes: null,
    });
  });

  it("has no score when nobody voted", () => {
    expect(normalizeTmdb({ id: 1, vote_average: 0, vote_count: 0 }, "tv").score).toBeNull();
  });

  it("maps TVmaze shows by network country", () => {
    const item = normalizeTvmaze({
      id: 3,
      name: "Sample",
      language: "Japanese",
      premiered: "2019-01-01",
      status: "Ended",
      genres: ["Drama"],
      rating: { average: 7.5 },
      image: { original: "https://static.tvmaze.com/a.jpg" },
      summary: "<p>Synthetic.</p>",
    });
    expect(item).toMatchObject({ kind: "jdrama", status: "finished", score: 75 });
  });

  it("treats TVmaze's Anime genre as anime, not a J-drama", () => {
    expect(normalizeTvmaze({ id: 4, language: "Japanese", genres: ["Anime"] }).kind).toBe("anime");
  });
});

describe("catalog routes", () => {
  it("serves the second identical request from KV", async () => {
    const kv = fakeKv();
    const env = fakeEnv({ CATALOG_CACHE: kv });
    const calls = mockUpstream(vi);
    await call("/catalog/search?q=synthetic&kind=movie", {}, env);
    await call("/catalog/search?q=synthetic&kind=movie", {}, env);
    expect(calls).toHaveLength(1);
    expect([...kv.store.keys()]).toEqual(["v1:search:movie:synthetic"]);
  });

  it("uses TMDB with the key and never leaks it to the client", async () => {
    const calls = mockUpstream(vi);
    const env = fakeEnv({ TMDB_API_KEY: "abc123secret" });
    const res = await call("/catalog/discover?kind=kdrama&mood=feels", {}, env);
    expect(res.status).toBe(200);
    expect(await res.text()).not.toContain("abc123secret");
    const url = calls[0]!.url;
    expect(url.pathname).toBe("/3/discover/tv");
    expect(url.searchParams.get("with_origin_country")).toBe("KR");
    expect(url.searchParams.get("without_genres")).toContain("16");
  });

  it("sends v4 tokens as a bearer header", async () => {
    const calls = mockUpstream(vi);
    await call("/catalog/discover?kind=movie", {}, fakeEnv({ TMDB_API_KEY: "eyJtoken" }));
    const init = calls[0]!.init!;
    expect((init.headers as Record<string, string>).Authorization).toBe("Bearer eyJtoken");
    expect(calls[0]!.url.searchParams.has("api_key")).toBe(false);
  });

  it("search asks TVmaze and Cinemeta for shows without a TMDB key", async () => {
    const calls = mockUpstream(vi);
    await call("/catalog/search?q=sample&kind=series");
    expect(calls.map((c) => c.url.hostname).sort()).toEqual([
      "api.tvmaze.com",
      "v3-cinemeta.strem.io",
    ]);
  });

  it("maps provider failures to 502 without details", async () => {
    mockUpstream(vi, () => new Response("boom secret", { status: 500 }));
    const res = await call("/catalog/search?q=synthetic&kind=movie");
    expect(res.status).toBe(502);
    expect(await res.json()).toEqual({ error: "upstream_error" });
  });

  it("refuses provider redirects", async () => {
    const calls = mockUpstream(vi, () =>
      new Response(null, { status: 302, headers: { Location: "https://evil.example" } }),
    );
    const res = await call("/catalog/search?q=synthetic&kind=movie");
    expect(res.status).toBe(502);
    expect(calls).toHaveLength(1);
    expect(calls[0]!.init!.redirect).toBe("manual");
  });
});

describe("image proxy", () => {
  const img = (u: string) => `/catalog/image?u=${encodeURIComponent(u)}`;

  it("returns the image with a long public cache", async () => {
    mockUpstream(vi);
    const res = await call(img("https://s4.anilist.co/file/a.png"));
    expect(res.status).toBe(200);
    expect(res.headers.get("Content-Type")).toBe("image/png");
    expect(res.headers.get("Cache-Control")).toContain("max-age=604800");
  });

  it("refuses non-image content from an allowed host", async () => {
    mockUpstream(vi, () => new Response("<html>", { headers: { "Content-Type": "text/html" } }));
    expect((await call(img("https://s4.anilist.co/file/a.png"))).status).toBe(502);
  });

  it("refuses redirects away from the allowlist", async () => {
    mockUpstream(vi, () =>
      new Response(null, { status: 301, headers: { Location: "https://evil.example/a.png" } }),
    );
    expect((await call(img("https://s4.anilist.co/file/a.png"))).status).toBe(502);
  });

  it("uses the separate image rate limit", async () => {
    mockUpstream(vi);
    const env = fakeEnv();
    await call(img("https://s4.anilist.co/file/a.png"), {}, env);
    expect((env.IMAGE_LIMITER as unknown as { keys: string[] }).keys).toHaveLength(1);
    expect((env.RATE_LIMITER as unknown as { keys: string[] }).keys).toHaveLength(0);
  });
});

describe("batch match for imports", () => {
  it("caps a batch at 15 titles", async () => {
    mockUpstream(vi);
    const items = Array.from({ length: 16 }, (_, i) => ({ q: `t${i}` }));
    expect((await postJson("/catalog/match", { items })).status).toBe(400);
  });

  it("screen titles go to TVmaze without a TMDB key; movies are skipped", async () => {
    const calls = mockUpstream(vi);
    const res = await postJson("/catalog/match", {
      items: [{ q: "Synthetic Drama", kind: "kdrama" }, { q: "Film", kind: "movie" }],
    });
    const body = (await res.json()) as { results: unknown[][] };
    expect(body.results).toHaveLength(2);
    expect(calls.filter((c) => c.url.hostname === "api.tvmaze.com")).toHaveLength(1);
  });
});
