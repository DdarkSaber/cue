import { afterEach, describe, expect, it, vi } from "vitest";
import { fakeEnv, fakeKv, mockUpstream, postJson } from "./helpers";

afterEach(() => vi.restoreAllMocks());

const profile = {
  liked: [
    { title: "Frieren", kind: "anime", year: 2023, rating: 10 },
    { title: "Solo Leveling", kind: "manhwa" },
  ],
  disliked: [{ title: "Bad Show" }],
  kinds: ["anime", "manhwa", "kdrama"],
};
const reply = (items: unknown[]) =>
  Response.json({ choices: [{ message: { content: JSON.stringify({ suggestions: items }) } }] });

describe("POST /ai/recommend", () => {
  it("answers 503 without keys", async () => {
    const res = await postJson("/ai/recommend", profile, fakeEnv({ CATALOG_CACHE: fakeKv() }));
    expect(res.status).toBe(503);
  });

  it("rejects oversized or malformed profiles", async () => {
    const env = fakeEnv({ GROQ_API_KEY: "k", CATALOG_CACHE: fakeKv() });
    const many = Array.from({ length: 26 }, (_, i) => ({ title: `t${i}`, kind: "anime" }));
    expect((await postJson("/ai/recommend", { ...profile, liked: many }, env)).status).toBe(400);
    expect((await postJson("/ai/recommend", { ...profile, liked: [] }, env)).status).toBe(400);
    expect((await postJson("/ai/recommend", { ...profile, kinds: ["novel"] }, env)).status).toBe(400);
    expect((await postJson("/ai/recommend", { ...profile, mood: "x".repeat(201) }, env)).status).toBe(400);
    const dis = Array.from({ length: 11 }, (_, i) => ({ title: `d${i}` }));
    expect((await postJson("/ai/recommend", { ...profile, disliked: dis }, env)).status).toBe(400);
  });

  it("keeps only valid items citing a liked title", async () => {
    mockUpstream(vi, () =>
      reply([
        { title: "Mushishi", kind: "anime", year: 2005, because: "frieren", why: "Quiet wandering." },
        { title: "Made Up", kind: "anime", because: "Not Liked", why: "x" },
        { title: "Frieren", kind: "anime", because: "Frieren", why: "dupe of liked" },
        { title: "Bad Show", kind: "anime", because: "Frieren", why: "disliked" },
        { title: "Tower of God", kind: "manga", because: "Solo Leveling", why: "kind not enabled" },
        { title: "Noblesse", kind: "manhwa", because: "Solo Leveling", why: "" },
        { title: "Sweet Home", kind: "kdrama", year: 3000, because: "Solo Leveling", why: "Dark action." },
        "junk",
      ]),
    );
    const res = await postJson("/ai/recommend", profile, fakeEnv({ GROQ_API_KEY: "k", CATALOG_CACHE: fakeKv() }));
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({
      provider: "groq",
      suggestions: [
        { title: "Mushishi", kind: "anime", year: 2005, because: "Frieren", why: "Quiet wandering." },
        { title: "Sweet Home", kind: "kdrama", because: "Solo Leveling", why: "Dark action." },
      ],
    });
  });

  it("falls back to Gemini and caches by profile hash", async () => {
    const good = { title: "Mushishi", kind: "anime", because: "Frieren", why: "Quiet." };
    const calls = mockUpstream(vi, (url) =>
      url.hostname === "api.groq.com"
        ? new Response("busy", { status: 500 })
        : Response.json({ candidates: [{ content: { parts: [{ text: JSON.stringify({ suggestions: [good] }) }] } }] }),
    );
    const kv = fakeKv();
    const env = fakeEnv({ GROQ_API_KEY: "k", GEMINI_API_KEY: "g", CATALOG_CACHE: kv });
    const first = await (await postJson("/ai/recommend", profile, env)).json();
    expect(first).toEqual({ provider: "gemini", suggestions: [good] });
    const n = calls.length;
    const reordered = { ...profile, liked: [...profile.liked].reverse(), kinds: [...profile.kinds].reverse() };
    expect(await (await postJson("/ai/recommend", reordered, env)).json()).toEqual(first);
    expect(calls.length).toBe(n);
    const keys = [...kv.store.keys()].filter((k) => k.startsWith("ai:rec:"));
    expect(keys).toHaveLength(1);
    expect(keys[0]).not.toMatch(/frieren/i);
  });

  it("answers 502 when every provider gives nothing usable", async () => {
    mockUpstream(vi, () => reply([{ title: "X", kind: "anime", because: "nope", why: "y" }]));
    const res = await postJson("/ai/recommend", profile, fakeEnv({ GROQ_API_KEY: "k", CATALOG_CACHE: fakeKv() }));
    expect(res.status).toBe(502);
  });
});
