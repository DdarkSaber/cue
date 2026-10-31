import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { MAX_BODY_BYTES } from "../src/middleware";
import { isAllowedImageUrl } from "../src/schemas";
import {
  APP_ORIGIN,
  call,
  fakeEnv,
  fakeLimiter,
  mockUpstream,
  postJson,
} from "./helpers";

beforeEach(() => {
  mockUpstream(vi);
});
afterEach(() => vi.restoreAllMocks());

describe("fixed endpoints only", () => {
  it.each([
    "/catalog/discover?kind=anime",
    "/catalog/discover?kind=manhwa&mood=hype&page=2",
    "/catalog/search?q=frieren",
    "/catalog/image?u=https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/x.jpg",
  ])("GET %s is served", async (path) => {
    const res = await call(path);
    expect(res.status).toBe(200);
  });

  it.each([
    "/catalog/discover?kind=kdrama",
    "/catalog/title/tmdb/1399",
    "/catalog/providers/1399?region=IN",
    "/catalog/providers/1399",
  ])("GET %s answers 503 not_configured without a TMDB key", async (path) => {
    const res = await call(path);
    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({ error: "not_configured" });
  });

  it("a title the provider does not have is 404", async () => {
    const res = await call("/catalog/title/anilist/154587");
    expect(res.status).toBe(404);
  });

  it("POST /oauth/:provider/token validates then answers 501", async () => {
    const res = await postJson("/oauth/anilist/token", {
      code: "abc",
      redirectUri: "https://cue.example/oauth/anilist",
    });
    expect(res.status).toBe(501);
  });

  it("POST /ai/mood validates then answers 501", async () => {
    const res = await postJson("/ai/mood", { text: "short, funny, new anime" });
    expect(res.status).toBe(501);
  });

  it.each([
    "/",
    "/health",
    "/proxy?url=https://example.com",
    "/catalog/graphql",
    "/catalog/title/anilist",
    "/import/mal/list",
  ])("unknown route %s is 404", async (path) => {
    const res = await call(path);
    expect(res.status).toBe(404);
    expect(await res.json()).toEqual({ error: "not_found" });
  });

  it("wrong method is 404, not a pass-through", async () => {
    expect((await call("/ai/mood")).status).toBe(404);
    expect((await call("/catalog/search?q=x", { method: "POST" })).status).toBe(
      404,
    );
  });
});

describe("input validation", () => {
  it.each([
    ["/catalog/discover", ["kind"]],
    ["/catalog/discover?kind=podcast", ["kind"]],
    ["/catalog/discover?kind=anime&mood=angry", ["mood"]],
    ["/catalog/discover?kind=anime&page=0", ["page"]],
    ["/catalog/discover?kind=anime&page=51", ["page"]],
    ["/catalog/title/imdb/1", ["provider"]],
    ["/catalog/title/anilist/abc", ["id"]],
    ["/catalog/title/anilist/1234567890123", ["id"]],
    ["/catalog/search", ["q"]],
    ["/catalog/search?q=%20%20", ["q"]],
    [`/catalog/search?q=${"a".repeat(201)}`, ["q"]],
    ["/catalog/providers/1399?region=india", ["region"]],
  ])("%s -> 400 naming %j", async (path, fields) => {
    const res = await call(path);
    expect(res.status).toBe(400);
    expect(await res.json()).toEqual({ error: "invalid_request", fields });
  });

  it("error bodies never echo the submitted value", async () => {
    const secret = "my-private-watch-history-title";
    const res = await call(`/catalog/discover?kind=${secret}`);
    expect(await res.text()).not.toContain(secret);
  });

  it("oauth rejects unknown providers and bad bodies", async () => {
    const good = { code: "c", redirectUri: "https://cue.example/cb" };
    expect((await postJson("/oauth/google/token", good)).status).toBe(400);
    expect((await postJson("/oauth/mal/token", {})).status).toBe(400);
    expect(
      (await postJson("/oauth/mal/token", { ...good, codeVerifier: "short" }))
        .status,
    ).toBe(400);
    const bad = await call("/oauth/mal/token", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{not json",
    });
    expect(bad.status).toBe(400);
  });

  it("ai mood caps text at 200 characters", async () => {
    expect((await postJson("/ai/mood", { text: "" })).status).toBe(400);
    expect((await postJson("/ai/mood", { text: "x".repeat(201) })).status).toBe(
      400,
    );
    expect((await postJson("/ai/mood", { text: "x".repeat(200) })).status).toBe(
      501,
    );
  });
});

describe("image host allowlist", () => {
  it.each([
    "https://s4.anilist.co/file/a.jpg",
    "https://image.tmdb.org/t/p/w500/a.jpg",
    "https://static.tvmaze.com/uploads/a.jpg",
  ])("allows %s", (u) => expect(isAllowedImageUrl(u)).toBe(true));

  it.each([
    "http://s4.anilist.co/file/a.jpg",
    "https://evil.example/a.jpg",
    "https://s4.anilist.co.evil.example/a.jpg",
    "https://evil.example/?h=s4.anilist.co",
    "https://user:pw@s4.anilist.co/a.jpg",
    "https://s4.anilist.co:8443/a.jpg",
    "https://169.254.169.254/latest/meta-data",
    "file:///etc/passwd",
    "javascript:alert(1)",
    "not a url",
  ])("rejects %s", (u) => expect(isAllowedImageUrl(u)).toBe(false));

  it("the image route refuses non-allowlisted hosts", async () => {
    const res = await call(
      `/catalog/image?u=${encodeURIComponent("https://evil.example/x.png")}`,
    );
    expect(res.status).toBe(400);
  });
});

describe("CORS and origins", () => {
  it("allows the app origin and echoes it", async () => {
    const res = await call("/catalog/search?q=x", {
      headers: { Origin: APP_ORIGIN },
    });
    expect(res.status).toBe(200);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe(APP_ORIGIN);
  });

  it("rejects other browser origins", async () => {
    const res = await call("/catalog/search?q=x", {
      headers: { Origin: "https://evil.example" },
    });
    expect(res.status).toBe(403);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBeNull();
  });

  it("answers preflight for the app origin", async () => {
    const res = await call("/ai/mood", {
      method: "OPTIONS",
      headers: {
        Origin: APP_ORIGIN,
        "Access-Control-Request-Method": "POST",
      },
    });
    expect(res.status).toBe(204);
    expect(res.headers.get("Access-Control-Allow-Methods")).toContain("POST");
  });

  it("lets native clients without an Origin through", async () => {
    expect((await call("/catalog/search?q=x")).status).toBe(200);
  });
});

describe("request size cap", () => {
  it(`rejects bodies over ${MAX_BODY_BYTES} bytes with 413`, async () => {
    const res = await postJson("/ai/mood", {
      text: "x",
      pad: "y".repeat(MAX_BODY_BYTES),
    });
    expect(res.status).toBe(413);
    expect(await res.json()).toEqual({ error: "payload_too_large" });
  });
});

describe("rate limiting", () => {
  it("limits per client IP and returns 429 with Retry-After", async () => {
    const env = fakeEnv({ RATE_LIMITER: fakeLimiter(2) });
    const headers = { "CF-Connecting-IP": "203.0.113.7" };
    expect((await call("/catalog/search?q=x", { headers }, env)).status).toBe(
      200,
    );
    expect((await call("/catalog/search?q=x", { headers }, env)).status).toBe(
      200,
    );
    const third = await call("/catalog/search?q=x", { headers }, env);
    expect(third.status).toBe(429);
    expect(third.headers.get("Retry-After")).toBe("60");
    const other = await call(
      "/catalog/search?q=x",
      { headers: { "CF-Connecting-IP": "203.0.113.8" } },
      env,
    );
    expect(other.status).toBe(200);
  });

  it("fails closed when the limiter binding is missing", async () => {
    const env = fakeEnv({ RATE_LIMITER: undefined as unknown as RateLimit });
    expect((await call("/catalog/search?q=x", {}, env)).status).toBe(503);
  });
});

describe("logging", () => {
  it("logs route pattern and status, never query, body or IP", async () => {
    const lines: string[] = [];
    vi.spyOn(console, "log").mockImplementation((m: unknown) => {
      lines.push(String(m));
    });
    vi.spyOn(console, "error").mockImplementation((m: unknown) => {
      lines.push(String(m));
    });

    await call("/catalog/search?q=secret-title-query", {
      headers: { "CF-Connecting-IP": "198.51.100.23" },
    });
    await postJson("/ai/mood", { text: "secret mood sentence" });

    const all = lines.join("\n");
    expect(all).not.toContain("secret");
    expect(all).not.toContain("198.51.100.23");
    expect(JSON.parse(lines[0]!)).toMatchObject({
      m: "GET",
      r: "/catalog/search",
      s: 200,
    });
  });
});

describe("hardening added after the security review", () => {
  it("sends security headers on every response", async () => {
    for (const res of [
      await call("/catalog/discover?kind=anime&page=0"),
      await call("/nope"),
      await postJson("/ai/mood", { text: "" }),
    ]) {
      expect(res.headers.get("X-Content-Type-Options")).toBe("nosniff");
      expect(res.headers.get("Referrer-Policy")).toBe("no-referrer");
      expect(res.headers.get("Cache-Control")).toBe("no-store");
      expect(res.headers.get("Content-Security-Policy")).toContain(
        "default-src 'none'",
      );
    }
  });

  it("ignores POST bodies that are not application/json", async () => {
    const res = await call("/ai/mood", {
      method: "POST",
      headers: { "Content-Type": "text/plain" },
      body: JSON.stringify({ text: "hello" }),
    });
    expect(res.status).toBe(400);
  });

  it("accepts application/json with a charset", async () => {
    const res = await call("/ai/mood", {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=utf-8" },
      body: JSON.stringify({ text: "hello" }),
    });
    expect(res.status).toBe(501);
  });

  it("caps streamed bodies that send no Content-Length", async () => {
    const chunk = new TextEncoder().encode("x".repeat(1024));
    let sent = 0;
    const body = new ReadableStream<Uint8Array>({
      pull(ctrl) {
        if (sent++ < 12) ctrl.enqueue(chunk);
        else ctrl.close();
      },
    });
    const res = await call("/ai/mood", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
      // @ts-expect-error Node/undici needs this for streamed request bodies.
      duplex: "half",
    });
    expect(res.status).toBe(413);
  });

  it.each([
    "https://s4.anilist.co@evil.example/a.jpg",
    "https://evil.example\@s4.anilist.co/a.jpg",
    "https://S4.ANILIST.CO.evil.example/a.jpg",
    "https://s4.anilist.co%2F@evil.example/a.jpg",
  ])("image allowlist rejects disguised host %s", (u) =>
    expect(isAllowedImageUrl(u)).toBe(false),
  );

  it("treats the literal 'null' origin as a foreign origin", async () => {
    const res = await call("/catalog/search?q=x", { headers: { Origin: "null" } });
    expect(res.status).toBe(403);
  });
});
