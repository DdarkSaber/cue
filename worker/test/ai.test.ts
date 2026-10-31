import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanHints } from "../src/ai/mood";
import { fakeEnv, mockUpstream, postJson } from "./helpers";

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
    const res = await postJson("/ai/mood", { text: "something cosy", allowed }, fakeEnv({ GROQ_API_KEY: "k" }));
    expect(await res.json()).toEqual({ features: ["romance"], avoid: ["horror"], provider: "groq" });
    expect(calls[0]!.url.hostname).toBe("api.groq.com");
  });

  it("falls back to Gemini when Groq fails", async () => {
    mockUpstream(vi, (url) =>
      url.hostname === "api.groq.com"
        ? new Response("busy", { status: 429 })
        : Response.json({ candidates: [{ content: { parts: [{ text: '{"features":["comedy"],"avoid":[]}' }] } }] }),
    );
    const res = await postJson("/ai/mood", { text: "make me laugh", allowed }, fakeEnv({ GROQ_API_KEY: "k", GEMINI_API_KEY: "g" }));
    expect(await res.json()).toEqual({ features: ["comedy"], avoid: [], provider: "gemini" });
  });
});
