import { afterEach, describe, expect, it, vi } from "vitest";

import { BREAKER_THRESHOLD, isOpen } from "../src/resilience";
import { APP_ORIGIN, call, emptyUpstream, fakeEnv, mockUpstream, postJson } from "./helpers";

afterEach(() => vi.restoreAllMocks());

const anilistList = {
  data: {
    MediaListCollection: {
      lists: [
        {
          entries: [
            {
              status: "COMPLETED",
              score: 9,
              progress: 12,
              repeat: 1,
              completedAt: { year: 2024, month: 5, day: 2 },
              media: { id: 11, idMal: 22, countryOfOrigin: "KR", type: "MANGA", title: { english: "Synthetic", romaji: null, native: null } },
            },
            {
              status: "PLANNING",
              score: 0,
              progress: 0,
              repeat: 0,
              completedAt: { year: null, month: null, day: null },
              media: { id: 12, idMal: null, countryOfOrigin: "JP", type: "ANIME", title: { english: null, romaji: "Romaji Only", native: null } },
            },
          ],
        },
      ],
    },
  },
};

describe("list imports", () => {
  it("rejects usernames that are not plain names", async () => {
    for (const bad of ["a", "has space", "x".repeat(33), "../etc"]) {
      expect((await call(`/import/mal/user/${encodeURIComponent(bad)}`)).status).toBe(400);
    }
  });

  it("MAL by username needs the client id", async () => {
    mockUpstream(vi);
    expect((await call("/import/mal/user/someone")).status).toBe(503);
  });

  it("MAL by username sends the client id header and follows paging on MAL only", async () => {
    const calls = mockUpstream(vi, (url) =>
      Response.json({
        data: [{ node: { id: 5, title: "Synthetic" }, list_status: { status: "completed", score: 0, num_times_rewatched: 2 } }],
        paging: url.searchParams.get("offset") ? {} : { next: "https://evil.example/next" },
      }),
    );
    const res = await call("/import/mal/user/someone", {}, fakeEnv({ MAL_CLIENT_ID: "cid" }));
    const { entries } = (await res.json()) as { entries: Record<string, unknown>[] };
    expect(calls.every((c) => c.url.hostname === "api.myanimelist.net")).toBe(true);
    expect((calls[0]!.init!.headers as Record<string, string>)["X-MAL-CLIENT-ID"]).toBe("cid");
    expect(entries[0]).toMatchObject({ malId: 5, score: null, repeat: 2 });
  });

  it("MAL entries carry the comic format and when the entry last changed", async () => {
    mockUpstream(vi, (url) =>
      Response.json({
        data: url.pathname.endsWith("/mangalist")
          ? [{ node: { id: 7, title: "Synthetic comic", media_type: "manhwa" }, list_status: { status: "reading", updated_at: "2026-10-12T08:00:00+00:00" } }]
          : [{ node: { id: 5, title: "Synthetic" }, list_status: { status: "watching", updated_at: "bad" } }],
      }),
    );
    const res = await call("/import/mal/user/someone", {}, fakeEnv({ MAL_CLIENT_ID: "cid" }));
    const { entries } = (await res.json()) as { entries: Record<string, unknown>[] };
    expect(entries).toContainEqual(expect.objectContaining({ malId: 7, kind: "manhwa", updatedAt: "2026-10-12" }));
    expect(entries).toContainEqual(expect.objectContaining({ malId: 5, kind: "anime", updatedAt: null }));
  });

  it("signed-in lists need a bearer token and never log it", async () => {
    const lines: string[] = [];
    vi.spyOn(console, "log").mockImplementation((m: unknown) => lines.push(String(m)));
    mockUpstream(vi, () => Response.json({ data: [] }));
    expect((await postJson("/import/mal/list", {})).status).toBe(400);
    const token = "secret-token-value-123";
    const res = await call("/import/mal/list", {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, Origin: APP_ORIGIN },
    });
    expect(res.status).toBe(200);
    expect(lines.join("\n")).not.toContain(token);
  });

  it("CORS allows the Authorization header for the app", async () => {
    const res = await call("/import/mal/list", {
      method: "OPTIONS",
      headers: { Origin: APP_ORIGIN, "Access-Control-Request-Method": "POST", "Access-Control-Request-Headers": "authorization" },
    });
    expect(res.headers.get("Access-Control-Allow-Headers")?.toLowerCase()).toContain("authorization");
  });

  it("oauth config reports only what is set up", async () => {
    const res = await call("/oauth/config", {}, fakeEnv({ MAL_CLIENT_ID: "123" }));
    expect(await res.json()).toEqual({ mal: "123" });
  });

  it("refresh renews tokens with the client secret and keeps nothing", async () => {
    const calls = mockUpstream(vi, () => Response.json({ access_token: "new", refresh_token: "r2", expires_in: 3600 }));
    const env = fakeEnv({ MAL_CLIENT_ID: "cid", MAL_CLIENT_SECRET: "sec" });
    expect((await postJson("/oauth/mal/refresh", {}, env)).status).toBe(400);
    const res = await postJson("/oauth/mal/refresh", { refreshToken: "old-refresh-token" }, env);
    expect(await res.json()).toEqual({ accessToken: "new", refreshToken: "r2", expiresIn: 3600 });
    const sent = String(calls[0]!.init!.body);
    expect(sent).toContain("grant_type=refresh_token");
    expect(sent).toContain("client_secret=sec");
  });

  it("token exchange returns the tokens and their lifetime", async () => {
    mockUpstream(vi, () => Response.json({ access_token: "tok", refresh_token: "r", expires_in: 1 }));
    const env = fakeEnv({ MAL_CLIENT_ID: "cid" });
    const res = await postJson(
      "/oauth/mal/token",
      { code: "c", codeVerifier: "v".repeat(64), redirectUri: "cue://oauth/mal" },
      env,
    );
    expect(await res.json()).toEqual({ accessToken: "tok", refreshToken: "r", expiresIn: 1 });
  });

  describe("expired sign-in versus outage", () => {
    const bearer = { Authorization: "Bearer secret-token-value-123" };
    const viewer = () => call("/import/mal/list", { method: "POST", headers: bearer });
    const me = () => call("/import/mal/me", { method: "POST", headers: bearer });
    const refresh = () =>
      postJson("/oauth/mal/refresh", { refreshToken: "old-refresh-token" }, fakeEnv({ MAL_CLIENT_ID: "cid" }));
    const exchange = () =>
      postJson(
        "/oauth/mal/token",
        { code: "c", codeVerifier: "v".repeat(64), redirectUri: "cue://oauth/mal" },
        fakeEnv({ MAL_CLIENT_ID: "cid" }),
      );

    it.each([401, 403])("viewer list and me answer 401 token_expired on MAL %i", async (status) => {
      mockUpstream(vi, () => Response.json({ error: "invalid_token" }, { status }));
      for (const res of [await viewer(), await me()]) {
        expect(res.status).toBe(401);
        expect(await res.json()).toEqual({ error: "token_expired" });
      }
    });

    it.each([400, 401])("refresh and code exchange answer 401 token_expired on MAL %i", async (status) => {
      mockUpstream(vi, () => Response.json({ error: "invalid_grant" }, { status }));
      for (const res of [await refresh(), await exchange()]) {
        expect(res.status).toBe(401);
        expect(await res.json()).toEqual({ error: "token_expired" });
      }
    });

    it("an outage stays 502 upstream_error", async () => {
      mockUpstream(vi, () => new Response("down", { status: 500 }));
      for (const res of [await viewer(), await me(), await refresh()]) {
        expect(res.status).toBe(502);
        expect(await res.json()).toEqual({ error: "upstream_error" });
      }
      mockUpstream(vi, () => new Response("busy", { status: 429 }));
      expect((await refresh()).status).toBe(502);
    });

    it("a username import with a bad client id is not a sign-in problem", async () => {
      mockUpstream(vi, () => new Response("no", { status: 401 }));
      expect((await call("/import/mal/user/someone", {}, fakeEnv({ MAL_CLIENT_ID: "cid" }))).status).toBe(502);
    });

    it("401s never trip the circuit breaker and are not retried", async () => {
      const calls = mockUpstream(vi, () => new Response("no", { status: 401 }));
      for (let i = 0; i < BREAKER_THRESHOLD * 2; i++) expect((await me()).status).toBe(401);
      expect(calls).toHaveLength(BREAKER_THRESHOLD * 2);
      expect(isOpen("api.myanimelist.net")).toBe(false);
      vi.restoreAllMocks();
      mockUpstream(vi, () => Response.json({ name: "someone" }));
      expect(await (await me()).json()).toEqual({ name: "someone" });
    });

    it("never logs the token on a rejected sign-in", async () => {
      const lines: string[] = [];
      vi.spyOn(console, "error").mockImplementation((m: unknown) => lines.push(String(m)));
      vi.spyOn(console, "log").mockImplementation((m: unknown) => lines.push(String(m)));
      mockUpstream(vi, () => new Response("no", { status: 401 }));
      await viewer();
      expect(lines.join("\n")).not.toContain("secret-token-value-123");
    });
  });
});
