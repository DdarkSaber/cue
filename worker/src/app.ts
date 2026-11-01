import { Hono } from "hono";

import { proxyImage } from "./catalog/image";
import * as catalog from "./catalog/service";
import { NotConfiguredError, UpstreamError } from "./catalog/types";
import type { AppEnv } from "./env";
import * as lists from "./imports/lists";
import { SyncStore } from "./sync/store";
import { moodHints, underDailyCap } from "./ai/mood";
import { fail } from "./errors";
import {
  allowedOrigins,
  apiHeaders,
  bodyCap,
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
  matchBody,
  moodBody,
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
    c.header("Cache-Control", "public, max-age=3600");
    return c.json(body as object);
  };

  app.get("/catalog/discover", async (c) => {
    const q = check(c, discoverQuery, c.req.query());
    if (!q.ok) return q.res;
    const { value } = await catalog.discover(c.env, q.data.kind, q.data.mood, q.data.page);
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

  app.get("/sync/:id", async (c) => {
    const a = syncAuth(c);
    if ("res" in a) return a.res;
    const blob = await a.store.get(a.id, a.token);
    if (blob === null) return fail(c, 404, "not_found");
    if (blob === "forbidden") return fail(c, 403, "forbidden");
    return c.json(blob);
  });

  app.put("/sync/:id", async (c) => {
    const a = syncAuth(c);
    if ("res" in a) return a.res;
    const b = check(c, syncBody, await jsonBody(c));
    if (!b.ok) return b.res;
    const r = await a.store.put(a.id, a.token, b.data.version, b.data.data, Date.now());
    if (r.ok) return c.json({ version: r.version });
    if (r.reason === "conflict") return fail(c, 409, "conflict", { version: r.version });
    return fail(c, r.reason === "forbidden" ? 403 : 404, r.reason);
  });

  app.delete("/sync/:id", async (c) => {
    const a = syncAuth(c);
    if ("res" in a) return a.res;
    const r = await a.store.delete(a.id, a.token);
    if (r === "deleted") return c.json({ deleted: true });
    return fail(c, r === "forbidden" ? 403 : 404, r);
  });

  app.post("/ai/mood", async (c) => {
    const b = check(c, moodBody, await jsonBody(c));
    if (!b.ok) return b.res;
    if (!(c.env.GROQ_API_KEY || c.env.GEMINI_API_KEY)) return fail(c, 503, "not_configured");
    if (!(await underDailyCap(c.env.CATALOG_CACHE))) {
      c.header("Retry-After", "3600");
      return fail(c, 429, "rate_limited");
    }
    return c.json(await moodHints(c.env, b.data.text, b.data.allowed));
  });

  app.notFound((c) => fail(c, 404, "not_found"));

  app.onError((err, c) => {
    if (err instanceof NotConfiguredError) return fail(c, 503, "not_configured");
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
