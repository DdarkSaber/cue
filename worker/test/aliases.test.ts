import { afterEach, describe, expect, it, vi } from "vitest";

import { normalizeAlias } from "../src/catalog/mangadex";
import { call, emptyUpstream, fakeEnv, fakeKv, mockUpstream, postJson } from "./helpers";

afterEach(() => vi.restoreAllMocks());

const work = {
  id: "uuid-1",
  attributes: {
    title: { en: "Log-in Murim", ko: "로그인 무림" },
    altTitles: [{ en: "Murim Login" }, { ja: "ログイン武林" }, { en: "Murim Login" }],
    originalLanguage: "ko",
    links: { al: "120385", mal: "147389", kt: "999" },
  },
};

describe("MangaDex aliases", () => {
  it("collects every name once, with the AniList and MAL ids", () => {
    const a = normalizeAlias(work);
    expect(a.names).toEqual(["Log-in Murim", "로그인 무림", "Murim Login", "ログイン武林"]);
    expect(a).toMatchObject({ al: 120385, mal: 147389, lang: "ko" });
  });

  it("unknown links stay null, never zero", () => {
    const a = normalizeAlias({ attributes: { title: { en: "X" }, links: { al: "abc" } } });
    expect(a.al).toBeNull();
    expect(a.mal).toBeNull();
    expect(a.lang).toBeNull();
  });

  it("returns candidates per name and caches each name for a week", async () => {
    const kv = fakeKv();
    const calls = mockUpstream(vi, (url) =>
      url.hostname === "api.mangadex.org" ? Response.json({ data: [work] }) : emptyUpstream(url),
    );
    const env = fakeEnv({ CATALOG_CACHE: kv });
    const body = { items: [{ q: "Murim Login" }, { q: "Another One" }] };
    const first = await postJson("/catalog/aliases", body, env);
    const { results } = (await first.json()) as { results: { al: number }[][] };
    expect(results).toHaveLength(2);
    expect(results[0]![0]!.al).toBe(120385);
    expect(calls).toHaveLength(2);
    expect(calls[0]!.url.searchParams.get("title")).toBe("Murim Login");
    expect(calls[0]!.url.searchParams.get("limit")).toBe("5");

    await postJson("/catalog/aliases", body, env);
    expect(calls).toHaveLength(2); // second time came from the cache
    expect([...kv.store.keys()].sort()).toEqual(["v1:alias:another one", "v1:alias:murim login"]);
  });

  it("one failing lookup leaves that name empty, not the batch", async () => {
    mockUpstream(vi, (url) =>
      url.searchParams.get("title") === "Bad"
        ? new Response("no", { status: 500 })
        : Response.json({ data: [work] }),
    );
    const res = await postJson("/catalog/aliases", { items: [{ q: "Good" }, { q: "Bad" }] });
    const { results } = (await res.json()) as { results: unknown[][] };
    expect(results[0]).toHaveLength(1);
    expect(results[1]).toEqual([]);
  });

  it("validates the batch: 1 to 8 names of at most 160 characters", async () => {
    mockUpstream(vi);
    expect((await postJson("/catalog/aliases", { items: [] })).status).toBe(400);
    const nine = Array.from({ length: 9 }, (_, i) => ({ q: `t${i}` }));
    expect((await postJson("/catalog/aliases", { items: nine })).status).toBe(400);
    expect((await postJson("/catalog/aliases", { items: [{ q: "x".repeat(161) }] })).status).toBe(400);
    expect((await call("/catalog/aliases")).status).toBe(404);
  });

  it("never logs the names it looked up", async () => {
    const lines: string[] = [];
    vi.spyOn(console, "log").mockImplementation((m: unknown) => lines.push(String(m)));
    mockUpstream(vi, () => Response.json({ data: [] }));
    await postJson("/catalog/aliases", { items: [{ q: "secret-title-name" }] });
    expect(lines.join("\n")).not.toContain("secret-title-name");
  });
});
