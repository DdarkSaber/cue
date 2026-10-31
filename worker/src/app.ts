import { Hono } from "hono";

import { proxyImage } from "./catalog/image";
import * as catalog from "./catalog/service";
import { NotConfiguredError, UpstreamError } from "./catalog/types";
import type { AppEnv } from "./env";
import { fail } from "./errors";
import {
  apiHeaders,
  bodyCap,
  corsPolicy,
  originGuard,
  rateLimit,
  requestLog,
} from "./middleware";
import {
  discoverQuery,
  imageQuery,
  moodBody,
  oauthBody,
  oauthParams,
  providersParams,
  providersQuery,
  searchQuery,
  titleParams,
  titleQuery,
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

  const notYet = (c: Parameters<typeof fail>[0]) =>
    fail(c, 501, "not_implemented");

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

  app.post("/oauth/:provider/token", async (c) => {
    const p = check(c, oauthParams, c.req.param());
    if (!p.ok) return p.res;
    const b = check(c, oauthBody, await jsonBody(c));
    return b.ok ? notYet(c) : b.res;
  });

  app.post("/ai/mood", async (c) => {
    const b = check(c, moodBody, await jsonBody(c));
    return b.ok ? notYet(c) : b.res;
  });

  app.notFound((c) => fail(c, 404, "not_found"));

  app.onError((err, c) => {
    if (err instanceof NotConfiguredError) return fail(c, 503, "not_configured");
    if (err instanceof UpstreamError) return fail(c, 502, "upstream_error");
    // Error class only; messages can carry request data.
    console.error(JSON.stringify({ e: err.name, r: c.req.routePath }));
    return fail(c, 500, "internal");
  });

  return app;
}
