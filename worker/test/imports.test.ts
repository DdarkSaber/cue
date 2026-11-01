import { afterEach, describe, expect, it, vi } from "vitest";

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
});
