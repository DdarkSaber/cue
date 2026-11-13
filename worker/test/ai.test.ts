import { afterEach, describe, expect, it, vi } from "vitest";
import { env } from "cloudflare:workers";

import { DAILY_AI_CAP, DAILY_AI_CAP_PER_CLIENT, cleanHints, underDailyCap } from "../src/ai/mood";
import { aiEnv, call, fakeKv, mockUpstream, postJson } from "./helpers";

afterEach(() => vi.restoreAllMocks());

const allowed = ["romance", "comedy", "horror", "len:short"];

describe("mood hints", () => {
  it("keeps only allowed names", () => {
    expect(cleanHints(["Romance", "spaceships", "comedy", "comedy"], allowed, 6)).toEqual(["romance", "comedy"]);
    expect(cleanHints("nope", allowed, 6)).toEqual([]);
  });

  it("asks Groq and returns cleaned hints", async () => {
    const calls = mockUpstream(vi, () =>
      Response.json({
        choices: [{ message: { content: '{"features":["romance","aliens"],"avoid":["horror"]}' } }],
      }),
    );
    const res = await postJson("/ai/mood", { text: "something cosy", allowed }, aiEnv({ GROQ_API_KEY: "k", CATALOG_CACHE: fakeKv() }));
    expect(await res.json()).toEqual({ features: ["romance"], avoid: ["horror"], provider: "groq" });
    expect(calls[0]!.url.hostname).toBe("api.groq.com");
  });

  it("falls back to Gemini when Groq fails", async () => {
    mockUpstream(vi, (url) =>
      url.hostname === "api.groq.com"
        ? new Response("busy", { status: 429 })
        : Response.json({ candidates: [{ content: { parts: [{ text: '{"features":["comedy"],"avoid":[]}' }] } }] }),
    );
    const res = await postJson("/ai/mood", { text: "make me laugh", allowed }, aiEnv({ GROQ_API_KEY: "k", GEMINI_API_KEY: "g", CATALOG_CACHE: fakeKv() }));
    expect(await res.json()).toEqual({ features: ["comedy"], avoid: [], provider: "gemini" });
  });

  it("stops at the daily cap, counted in D1", async () => {
    const day = new Date("2026-11-01T10:00:00Z");
    await env.SYNC_DB.prepare("INSERT INTO ai_usage (day, used) VALUES (?, ?)").bind("2026-11-01", DAILY_AI_CAP - 1).run();
    expect(await underDailyCap(env.SYNC_DB, "client-a", day)).toBe(true);
    expect(await underDailyCap(env.SYNC_DB, "client-b", day)).toBe(false);
    // A new UTC day starts from zero.
    expect(await underDailyCap(env.SYNC_DB, "client-b", new Date("2026-11-02T10:00:00Z"))).toBe(true);
  });

  it("caps one client per day without spending the global cap, and stores no raw IP", async () => {
    const day = new Date("2026-11-01T10:00:00Z");
    for (let i = 0; i < DAILY_AI_CAP_PER_CLIENT; i++) expect(await underDailyCap(env.SYNC_DB, "203.0.113.9", day)).toBe(true);
    expect(await underDailyCap(env.SYNC_DB, "203.0.113.9", day)).toBe(false);
    expect(await underDailyCap(env.SYNC_DB, "203.0.113.10", day)).toBe(true);
    const rows = (await env.SYNC_DB.prepare("SELECT day, used FROM ai_usage").all<{ day: string; used: number }>()).results;
    expect(rows.find((r) => r.day === "2026-11-01")!.used).toBe(DAILY_AI_CAP_PER_CLIENT + 1);
    expect(rows.some((r) => r.day.includes("203.0.113"))).toBe(false);
    expect(rows.filter((r) => r.day !== "2026-11-01").every((r) => /^2026-11-01\|[a-f0-9]{16}$/.test(r.day))).toBe(true);
  });

  it("answers 429 with Retry-After 3600 once a client's daily slice is spent", async () => {
    mockUpstream(vi, () => Response.json({ choices: [{ message: { content: '{"features":[],"avoid":[]}' } }] }));
    const env2 = aiEnv();
    const headers = { "Content-Type": "application/json", "CF-Connecting-IP": "198.51.100.4" };
    const send = () => call("/ai/mood", { method: "POST", headers, body: JSON.stringify({ text: "calm", allowed }) }, env2);
    for (let i = 0; i < DAILY_AI_CAP_PER_CLIENT; i++) expect((await send()).status).toBe(200);
    const refused = await send();
    expect(refused.status).toBe(429);
    expect(await refused.json()).toEqual({ error: "rate_limited" });
    expect(refused.headers.get("Retry-After")).toBe("3600");
  });

  it("deletes counter rows older than a week, a few at a time", async () => {
    await env.SYNC_DB.prepare("INSERT INTO ai_usage (day, used) VALUES ('2026-10-01', 3), ('2026-10-01|0123456789abcdef', 3), ('2026-10-28', 1)").run();
    await underDailyCap(env.SYNC_DB, "x", new Date("2026-11-01T10:00:00Z"));
    const days = (await env.SYNC_DB.prepare("SELECT day FROM ai_usage").all<{ day: string }>()).results.map((r) => r.day);
    expect(days).not.toContain("2026-10-01");
    expect(days).not.toContain("2026-10-01|0123456789abcdef");
    expect(days).toContain("2026-10-28");
  });
});
