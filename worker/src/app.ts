import { Hono } from "hono";

import { proxyImage } from "./catalog/image";
import * as catalog from "./catalog/service";
import { AuthRejectedError, NotConfiguredError, UpstreamError } from "./catalog/types";
import type { AppEnv } from "./env";
import * as lists from "./imports/lists";
import { same, sha256Hex, SyncStore } from "./sync/store";
import { diagnosticsBody, diagnosticsId, diagnosticsToken } from "./diagnostics/schemas";
import { DiagnosticsStore } from "./diagnostics/store";
import { aiAvailable, moodHints, underDailyCap } from "./ai/mood";
import { shared } from "./resilience";
import {
  cachedRecommendations,
  hasAiKeys,
  profileKey,
  recommend,
  recommendBody,
  storeRecommendations,
} from "./ai/recommend";
import { fail } from "./errors";
import {
  allowedOrigins,
  apiHeaders,
  bodyCap,
  clientKey,
  corsPolicy,
  originGuard,
  rateLimit,
  requestLog,
} from "./middleware";
import {
  discoverQuery,
  bearer,
  aliasBody,
  imageQuery,
  listProvider,
  malSearchBody,
  matchBody,
  moodBody,
  namesBody,
  oauthBody,
  oauthParams,
  refreshBody,
  providersParams,
  providersQuery,
  searchQuery,
  syncBody,
  syncParams,
  titleParams,
  titleQuery,
  userParams,
} from "./schemas";
import { check, jsonBody } from "./validate";

/**
 * The fixed endpoint set. Nothing else is routable:
 * no URL pass-through, no arbitrary GraphQL. Routes without a handler yet
 * validate their input and answer 501.
 */
export function createApp() {
  type Ctx = Parameters<typeof fail>[0];
  // Every provider is failing right now: answer fast instead of waiting on timeouts.
  const aiDown = (c: Ctx) => {
    c.header("Retry-After", "30");
    return fail(c, 503, "unavailable");
  };
  const spendAi = async (c: Ctx): Promise<"ok" | "cap" | "store"> => {
    if (!c.env.SYNC_DB) return "store";
    try {
      return (await underDailyCap(c.env.SYNC_DB, clientKey(c))) ? "ok" : "cap";
    } catch {
      return "store";
    }
  };
  const aiRefused = (c: Ctx, why: "cap" | "store") => {
    c.header("Retry-After", why === "cap" ? "3600" : "60");
    return why === "cap" ? fail(c, 429, "rate_limited") : fail(c, 503, "unavailable");
  };

  const app = new Hono<AppEnv>();

  app.use(
    "*",
    requestLog,
    apiHeaders,
    originGuard,
    corsPolicy,
    bodyCap,
    rateLimit,
  );

  // Public catalog data: shared caches may keep it briefly.
  const publicJson = (c: Parameters<typeof fail>[0], body: unknown) => {
    // Empty answers (a gap, a missing key) are revalidated soon, not for an hour.
    const b = body as { items?: unknown[]; configured?: boolean } | null;
    const empty = Array.isArray(b?.items) && b.items.length === 0;
    c.header("Cache-Control", empty || b?.configured === false ? "public, max-age=60" : "public, max-age=3600");
    return c.json(body as object);
  };

  app.get("/catalog/discover", async (c) => {
    const q = check(c, discoverQuery, c.req.query());
    if (!q.ok) return q.res;
    const { value } = await catalog.discover(c.env, q.data.kind, q.data.mood, q.data.page, q.data.source);
    return publicJson(c, value);
  });

  app.get("/catalog/title/:provider/:id", async (c) => {
    const p = check(c, titleParams, c.req.param());
    if (!p.ok) return p.res;
    const q = check(c, titleQuery, c.req.query());
    if (!q.ok) return q.res;
    const { value } = await catalog.title(c.env, p.data.provider, p.data.id, q.data.type);
    return value ? publicJson(c, value) : fail(c, 404, "not_found");
  });

  // "More like this" for one title the person liked. The id is the only input.
  app.get("/catalog/recommendations/:provider/:id", async (c) => {
    const p = check(c, titleParams, c.req.param());
    if (!p.ok) return p.res;
    const q = check(c, titleQuery, c.req.query());
    if (!q.ok) return q.res;
    const value = await catalog.recommendations(c.env, p.data.provider, p.data.id, q.data.type);
    return publicJson(c, value);
  });

  app.get("/catalog/search", async (c) => {
    const q = check(c, searchQuery, c.req.query());
    if (!q.ok) return q.res;
    const { value } = await catalog.search(c.env, q.data.q, q.data.kind);
    return publicJson(c, { items: value });
  });

  app.get("/catalog/providers/:tmdbId", async (c) => {
    const p = check(c, providersParams, c.req.param());
    if (!p.ok) return p.res;
    const q = check(c, providersQuery, c.req.query());
    if (!q.ok) return q.res;
    const { value } = await catalog.providers(c.env, p.data.tmdbId, q.data.type, q.data.region);
    return publicJson(c, value);
  });

  app.get("/catalog/image", async (c) => {
    const q = check(c, imageQuery, c.req.query());
    return q.ok ? proxyImage(q.data.u) : q.res;
  });

  // Other names for comics (MangaDex), for imports. Names only; never logged.
  app.post("/catalog/aliases", async (c) => {
    const b = check(c, aliasBody, await jsonBody(c));
    if (!b.ok) return b.res;
    const results = await catalog.aliases(c.env, b.data.items.map((i) => i.q), b.data.source);
    return c.json({ results });
  });

  // MyAnimeList search for import titles AniList could not place. Names only; never logged.
  app.post("/catalog/mal-search", async (c) => {
    const b = check(c, malSearchBody, await jsonBody(c));
    if (!b.ok) return b.res;
    const results = await catalog.malSearch(
      c.env,
      b.data.items.map((i) => ({ q: i.q, type: i.kind ?? b.data.kind })),
    );
    return c.json({ results });
  });

  // Canonical names from Wikipedia for titles no catalog recognised. Names only; never logged.
  app.post("/catalog/names", async (c) => {
    const b = check(c, namesBody, await jsonBody(c));
    if (!b.ok) return b.res;
    const results = await catalog.names(c.env, b.data.items.map((i) => i.q), b.data.kind);
    return c.json({ results });
  });

  // Batch matching for imports. Titles only; never stored or logged.
  app.post("/catalog/match", async (c) => {
    const b = check(c, matchBody, await jsonBody(c));
    if (!b.ok) return b.res;
    const out = await catalog.match(c.env, b.data.items);
    return c.json(out);
  });

  // Which sign-in sources are set up. Client ids are public by design.
  app.get("/oauth/config", (c) => c.json(lists.oauthConfig(c.env)));

  app.post("/oauth/:provider/token", async (c) => {
    const p = check(c, oauthParams, c.req.param());
    if (!p.ok) return p.res;
    const b = check(c, oauthBody, await jsonBody(c));
    if (!b.ok) return b.res;
    // Only Cue's own callbacks: the app scheme or an allowed web origin.
    const redirect = b.data.redirectUri;
    const okRedirect =
      redirect === `cue://oauth/${p.data.provider}` ||
      [...allowedOrigins(c.env.ALLOWED_ORIGINS)].some(
        (o) => redirect === `${o}/auth.html`,
      );
    if (!okRedirect) return fail(c, 400, "invalid_request", { fields: ["redirectUri"] });
    const t = await lists.exchange(c.env, p.data.provider, b.data.code, redirect, b.data.codeVerifier);
    return c.json(t);
  });

  app.post("/oauth/:provider/refresh", async (c) => {
    const p = check(c, oauthParams, c.req.param());
    if (!p.ok) return p.res;
    const b = check(c, refreshBody, await jsonBody(c));
    if (!b.ok) return b.res;
    return c.json(await lists.refresh(c.env, p.data.provider, b.data.refreshToken));
  });

  // List imports. Tokens are used for this request only; nothing is kept.
  app.get("/import/mal/user/:name", async (c) => {
    const p = check(c, userParams, c.req.param());
    if (!p.ok) return p.res;
    return c.json({ entries: await lists.malByUser(c.env, p.data.name) });
  });

  // Who the token belongs to, so the app can show the account it is using.
  app.post("/import/:provider/me", async (c) => {
    const p = check(c, listProvider, c.req.param());
    if (!p.ok) return p.res;
    const token = bearer(c.req.header("Authorization"));
    if (!token) return fail(c, 400, "invalid_request", { fields: ["authorization"] });
    const name = await lists.malMe(token);
    return c.json({ name });
  });

  app.post("/import/:provider/list", async (c) => {
    const p = check(c, listProvider, c.req.param());
    if (!p.ok) return p.res;
    const token = bearer(c.req.header("Authorization"));
    if (!token) return fail(c, 400, "invalid_request", { fields: ["authorization"] });
    const entries = await lists.malViewer(token);
    return c.json({ entries });
  });

  // End-to-end encrypted sync. The token proves knowledge of the sync code.
  const syncAuth = (c: Parameters<typeof fail>[0]) => {
    const p = check(c, syncParams, c.req.param());
    if (!p.ok) return { res: p.res };
    const token = bearer(c.req.header("Authorization"));
    if (!token) return { res: fail(c, 400, "invalid_request", { fields: ["authorization"] }) };
    if (!c.env.SYNC_DB) return { res: fail(c, 503, "not_configured") };
    return { id: p.data.id, token, store: new SyncStore(c.env.SYNC_DB) };
  };

  // A wrong token answers 404 like a missing id, so ids cannot be probed.
  app.get("/sync/:id", async (c) => {
    const a = syncAuth(c);
    if ("res" in a) return a.res;
    const blob = await a.store.get(a.id, a.token);
    return blob === null ? fail(c, 404, "not_found") : c.json(blob);
  });

  app.put("/sync/:id", async (c) => {
    const a = syncAuth(c);
    if ("res" in a) return a.res;
    const b = check(c, syncBody, await jsonBody(c));
    if (!b.ok) return b.res;
    // Creates take new space: a much stricter per-IP limit than updates.
    if (b.data.version === 0) {
      const limiter = c.env.SYNC_CREATE_LIMITER ?? c.env.RATE_LIMITER;
      if (!limiter) return fail(c, 503, "unavailable");
      if (!(await limiter.limit({ key: clientKey(c) })).success) {
        c.header("Retry-After", "60");
        return fail(c, 429, "rate_limited");
      }
    }
    const r = await a.store.put(a.id, a.token, b.data.version, b.data.data, Date.now());
    if (r.ok) return c.json({ version: r.version });
    if (r.reason === "conflict") return fail(c, 409, "conflict", { version: r.version });
    if (r.reason === "quota_exceeded") {
      c.header("Retry-After", "86400");
      return fail(c, 429, "quota_exceeded");
    }
    return fail(c, 404, "not_found");
  });

  app.delete("/sync/:id", async (c) => {
    const a = syncAuth(c);
    if ("res" in a) return a.res;
    const r = await a.store.delete(a.id, a.token);
    return r === "deleted" ? c.json({ deleted: true }) : fail(c, 404, "not_found");
  });

  // Optional, client-consented technical diagnostics. CORS is not authorization.
  app.post("/diagnostics", async (c) => {
    if (c.req.header("Authorization") !== undefined || Object.keys(c.req.query()).length) {
      return fail(c, 400, "invalid_request");
    }
    const body = diagnosticsBody.safeParse(await jsonBody(c));
    if (!body.success) return fail(c, 400, "invalid_request");
    if (!c.env.SYNC_DB) return fail(c, 503, "unavailable");
    try {
      const result = await new DiagnosticsStore(c.env.SYNC_DB).create(body.data.events, Date.now());
      if (result.ok) {
        return c.json({ token: result.token, accepted: result.accepted, expiresAt: result.expiresAt });
      }
      c.header("Retry-After", "604800");
      return fail(c, 429, result.reason);
    } catch {
      return fail(c, 503, "unavailable");
    }
  });

  const diagnosticsAuth = async (c: Parameters<typeof fail>[0]) => {
    const id = diagnosticsId.safeParse(c.req.param("id"));
    const token = diagnosticsToken(c.req.header("Authorization"));
    if (!id.success || !token || !same(id.data, await sha256Hex(token))) {
      return { res: fail(c, 403, "forbidden") };
    }
    if (Object.keys(c.req.query()).length) return { res: fail(c, 400, "invalid_request") };
    if (!c.env.SYNC_DB) return { res: fail(c, 503, "unavailable") };
    return { id: id.data, store: new DiagnosticsStore(c.env.SYNC_DB) };
  };

  app.get("/diagnostics/:id", async (c) => {
    const a = await diagnosticsAuth(c);
    if ("res" in a) return a.res;
    try {
      const events = await a.store.get(a.id, Date.now());
      return events === null ? fail(c, 404, "not_found") : c.json({ events });
    } catch {
      return fail(c, 503, "unavailable");
    }
  });

  app.put("/diagnostics/:id", async (c) => {
    const a = await diagnosticsAuth(c);
    if ("res" in a) return a.res;
    // Fixed errors only: even arbitrary unknown field names are not echoed.
    const body = diagnosticsBody.safeParse(await jsonBody(c));
    if (!body.success) return fail(c, 400, "invalid_request");
    try {
      const result = await a.store.append(a.id, body.data.events, Date.now());
      if (result.ok) return c.json({ accepted: result.accepted, expiresAt: result.expiresAt });
      if (result.reason === "not_found") return fail(c, 404, "not_found");
      c.header("Retry-After", result.reason === "rate_limited" ? "5" : "604800");
      return fail(c, 429, result.reason);
    } catch {
      return fail(c, 503, "unavailable");
    }
  });

  app.post("/ai/mood", async (c) => {
    const b = check(c, moodBody, await jsonBody(c));
    if (!b.ok) return b.res;
    if (!(c.env.GROQ_API_KEY || c.env.GEMINI_API_KEY)) return fail(c, 503, "not_configured");
    if (!aiAvailable(c.env)) return aiDown(c);
    const cap = await spendAi(c);
    if (cap !== "ok") return aiRefused(c, cap);
    return c.json(await moodHints(c.env, b.data.text, b.data.allowed));
  });

  // Opt-in taste picks. Titles go to the AI provider for this request only.
  app.post("/ai/recommend", async (c) => {
    const b = check(c, recommendBody, await jsonBody(c));
    if (!b.ok) return b.res;
    if (!hasAiKeys(c.env)) return fail(c, 503, "not_configured");
    const key = await profileKey(b.data);
    const hit = await cachedRecommendations(c.env.CATALOG_CACHE, key);
    if (hit) return c.json(hit);
    if (!aiAvailable(c.env)) return aiDown(c);
    // Identical in-flight requests share one provider call and one cap unit.
    const out = await shared(key, async () => {
      const cap = await spendAi(c);
      if (cap !== "ok") return cap;
      const fresh = await recommend(c.env, b.data);
      await storeRecommendations(c.env.CATALOG_CACHE, key, fresh);
      return fresh;
    });
    return typeof out === "string" ? aiRefused(c, out) : c.json(out);
  });

  app.notFound((c) => fail(c, 404, "not_found"));

  app.onError((err, c) => {
    if (err instanceof NotConfiguredError) return fail(c, 503, "not_configured");
    if (err instanceof AuthRejectedError) {
      // The person's sign-in is no longer valid; the app renews or signs out.
      console.error(JSON.stringify({ e: "auth_rejected", m: err.message, r: c.req.routePath }));
      return fail(c, 401, "token_expired");
    }
    if (err instanceof UpstreamError) {
      // The message is a fixed reason or an HTTP status, never request data.
      console.error(JSON.stringify({ e: "upstream", m: err.message, r: c.req.routePath }));
      return fail(c, 502, "upstream_error");
    }
    // Error class only; messages can carry request data.
    console.error(JSON.stringify({ e: err.name, r: c.req.routePath }));
    return fail(c, 500, "internal");
  });

  return app;
}
