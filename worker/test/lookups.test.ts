import { afterEach, describe, expect, it, vi } from "vitest";

import { malQuery } from "../src/catalog/mal";
import { normalizeWiki, plainTitle } from "../src/catalog/wikipedia";
import { call, emptyUpstream, fakeEnv, fakeKv, fakeLimiter, mockUpstream, postJson } from "./helpers";

afterEach(() => vi.restoreAllMocks());

const node = (id: number, over: Record<string, unknown> = {}) => ({
  node: {
    id,
    title: `Synthetic Romaji ${id}`,
    alternative_titles: { en: `Synthetic English ${id}`, ja: "合成", synonyms: [`Alias ${id}`, ""] },
    media_type: "tv",
    start_date: "2020-04-01",
    status: "finished_airing",
    num_episodes: 12,
    nsfw: "white",
    rating: "pg_13",
    ...over,
  },
});

const malEnv = (over = {}) => fakeEnv({ MAL_CLIENT_ID: "client-id", CATALOG_CACHE: fakeKv(), ...over });

describe("MAL title search", () => {
  it("searches the right list with the client id, nsfw off, and returns cards with synonyms", async () => {
    const calls = mockUpstream(vi, (url) =>
      url.hostname === "api.myanimelist.net" ? Response.json({ data: [node(5)] }) : emptyUpstream(url),
    );
    const res = await postJson("/catalog/mal-search", { items: [{ q: "Some Name" }], kind: "anime" }, malEnv());
    expect(res.status).toBe(200);
    const { results } = (await res.json()) as { results: Record<string, unknown>[][] };
    expect(results[0]![0]).toMatchObject({
      provider: "mal",
      providerId: "5",
      providerKind: "anime",
      idMal: 5,
      kind: "anime",
      titleEn: "Synthetic English 5",
      synonyms: ["Alias 5"],
    });
    expect(calls).toHaveLength(1);
    const u = calls[0]!.url;
    expect(u.pathname).toBe("/v2/anime");
    expect(u.searchParams.get("q")).toBe("Some Name");
    expect(u.searchParams.get("nsfw")).toBe("false");
    expect(new Headers(calls[0]!.init?.headers).get("X-MAL-CLIENT-ID")).toBe("client-id");
  });

  it("drops adult entries, novels and music, and reads manhwa from the manga list", async () => {
    const calls = mockUpstream(vi, () =>
      Response.json({
        data: [
          node(1, { media_type: "manhwa", num_chapters: 80 }),
          node(2, { nsfw: "black" }),
          node(3, { media_type: "light_novel" }),
          node(4, { media_type: "novel" }),
          node(6, { rating: "rx" }),
        ],
      }),
    );
    const res = await postJson("/catalog/mal-search", { items: [{ q: "Comic" }], kind: "manga" }, malEnv());
    const { results } = (await res.json()) as { results: { providerId: string; kind: string }[][] };
    expect(results[0]!.map((i) => [i.providerId, i.kind])).toEqual([["1", "manhwa"]]);
    expect(calls[0]!.url.pathname).toBe("/v2/manga");
  });

  it("caches each name for a week and skips names MAL would refuse", async () => {
    const kv = fakeKv();
    const calls = mockUpstream(vi, () => Response.json({ data: [node(7)] }));
    const env = malEnv({ CATALOG_CACHE: kv });
    const body = { items: [{ q: "Cached Name" }, { q: "ab" }], kind: "anime" };
    const first = (await (await postJson("/catalog/mal-search", body, env)).json()) as { results: unknown[][] };
    expect(first.results[0]).toHaveLength(1);
    expect(first.results[1]).toEqual([]);
    expect(calls).toHaveLength(1); // "ab" is too short for MAL: never sent
    await postJson("/catalog/mal-search", body, env);
    expect(calls).toHaveLength(1);
    expect([...kv.store.keys()]).toContain("v1:malsearch:anime:cached name");
  });

  it("cuts long names to MAL's limit at a word boundary", () => {
    expect(malQuery("  a  ")).toBeNull();
    expect(malQuery("x".repeat(70))).toHaveLength(64);
    const long = "word ".repeat(20).trim();
    const q = malQuery(long)!;
    expect(q.length).toBeLessThanOrEqual(64);
    expect(q.endsWith("word")).toBe(true);
  });

  it("one failing name leaves that name empty, not the batch", async () => {
    mockUpstream(vi, (url) =>
      url.searchParams.get("q") === "Bad Name" ? new Response("no", { status: 500 }) : Response.json({ data: [node(1)] }),
    );
    const res = await postJson("/catalog/mal-search", { items: [{ q: "Good Name" }, { q: "Bad Name" }], kind: "anime" }, malEnv());
    const { results } = (await res.json()) as { results: unknown[][] };
    expect(results[0]).toHaveLength(1);
    expect(results[1]).toEqual([]);
  });

  it("answers 503 not_configured without a client id", async () => {
    mockUpstream(vi);
    const res = await postJson("/catalog/mal-search", { items: [{ q: "Name" }], kind: "anime" });
    expect(res.status).toBe(503);
  });

  it("validates: 1 to 8 names and a kind of anime or manga", async () => {
    mockUpstream(vi);
    const env = malEnv();
    expect((await postJson("/catalog/mal-search", { items: [], kind: "anime" }, env)).status).toBe(400);
    const nine = Array.from({ length: 9 }, (_, i) => ({ q: `t${i}` }));
    expect((await postJson("/catalog/mal-search", { items: nine, kind: "anime" }, env)).status).toBe(400);
    expect((await postJson("/catalog/mal-search", { items: [{ q: "x" }], kind: "kdrama" }, env)).status).toBe(400);
    expect((await postJson("/catalog/mal-search", { items: [{ q: "x" }] }, env)).status).toBe(400);
    expect((await call("/catalog/mal-search", {}, env)).status).toBe(404);
  });

  it("never logs the names it looked up", async () => {
    const lines: string[] = [];
    vi.spyOn(console, "log").mockImplementation((m: unknown) => lines.push(String(m)));
    mockUpstream(vi, () => Response.json({ data: [] }));
    await postJson("/catalog/mal-search", { items: [{ q: "secret-title-name" }], kind: "manga" }, malEnv());
    expect(lines.join("\n")).not.toContain("secret-title-name");
  });
});

const wikiBody = {
  query: {
    pages: [
      {
        pageid: 2,
        title: "Synthetic Show (manga)",
        index: 2,
        redirects: [{ ns: 0, title: "Gousei Shou" }, { ns: 0, title: "Synthetic Show (manga)" }],
      },
      { pageid: 1, title: "Synthetic Story", index: 1, redirects: [{ ns: 0, title: "Story of Synthesis" }] },
      { pageid: 3, title: "Synthetic (disambiguation)", index: 3, pageprops: { disambiguation: "" } },
      { pageid: 4, title: "List of Synthetic Story episodes", index: 4 },
    ],
  },
};

describe("Wikipedia canonical names", () => {
  it("orders articles by search rank, strips disambiguators and drops lists and disambiguation pages", () => {
    expect(plainTitle("Pluto (2023 TV series)")).toBe("Pluto");
    expect(normalizeWiki(wikiBody)).toEqual([
      { title: "Synthetic Story", names: ["Story of Synthesis"] },
      { title: "Synthetic Show", names: ["Gousei Shou"] },
    ]);
    expect(normalizeWiki(null)).toEqual([]);
  });

  it("asks the search API with a kind hint, keyless, and caches per name and kind", async () => {
    const kv = fakeKv();
    const calls = mockUpstream(vi, (url) =>
      url.hostname === "en.wikipedia.org" ? Response.json(wikiBody) : emptyUpstream(url),
    );
    const env = fakeEnv({ CATALOG_CACHE: kv });
    const body = { items: [{ q: "Messy Name" }], kind: "anime" };
    const res = await postJson("/catalog/names", body, env);
    expect(res.status).toBe(200);
    const { results } = (await res.json()) as { results: { title: string }[][] };
    expect(results[0]![0]!.title).toBe("Synthetic Story");
    expect(calls).toHaveLength(1);
    const u = calls[0]!.url;
    expect(u.pathname).toBe("/w/api.php");
    expect(u.searchParams.get("generator")).toBe("search");
    expect(u.searchParams.get("gsrsearch")).toBe("Messy Name anime");
    expect(u.searchParams.get("prop")).toBe("redirects|pageprops");
    await postJson("/catalog/names", body, env);
    expect(calls).toHaveLength(1);
    expect([...kv.store.keys()]).toEqual(["v1:wiki:anime:messy name"]);
  });

  it("sends the bare name when no kind is given; a failure is an empty list", async () => {
    const calls = mockUpstream(vi, () => new Response("down", { status: 503 }));
    const res = await postJson("/catalog/names", { items: [{ q: "Name" }] });
    expect(res.status).toBe(200);
    expect(((await res.json()) as { results: unknown[][] }).results).toEqual([[]]);
    expect(calls[0]!.url.searchParams.get("gsrsearch")).toBe("Name");
  });

  it("validates 1 to 8 names", async () => {
    mockUpstream(vi);
    expect((await postJson("/catalog/names", { items: [] })).status).toBe(400);
    const nine = Array.from({ length: 9 }, (_, i) => ({ q: `t${i}` }));
    expect((await postJson("/catalog/names", { items: nine })).status).toBe(400);
    expect((await postJson("/catalog/names", { items: [{ q: "a" }], kind: "book" })).status).toBe(400);
  });
});

describe("rate limiting of lookups", () => {
  it("uses LOOKUP_LIMITER for MAL search and names, apart from the heavy routes", async () => {
    mockUpstream(vi, () => Response.json({ data: [], query: { pages: [] } }));
    const lookup = fakeLimiter(2);
    const heavy = fakeLimiter(1000);
    const env = malEnv({ LOOKUP_LIMITER: lookup, HEAVY_LIMITER: heavy });
    expect((await postJson("/catalog/mal-search", { items: [{ q: "abc" }], kind: "anime" }, env)).status).toBe(200);
    expect((await postJson("/catalog/names", { items: [{ q: "abc" }] }, env)).status).toBe(200);
    const third = await postJson("/catalog/names", { items: [{ q: "abc" }] }, env);
    expect(third.status).toBe(429);
    expect(third.headers.get("Retry-After")).toBe("60");
    expect(heavy.keys).toHaveLength(0);
    expect((await postJson("/catalog/aliases", { items: [{ q: "abc" }] }, env)).status).toBe(200);
  });
});
