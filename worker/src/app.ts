import { Hono } from "hono";

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
} from "./schemas";
import { check, jsonBody } from "./validate";

/**
 * The fixed endpoint set from CUE-HANDOFF 7.4. Nothing else is routable:
 * no URL pass-through, no arbitrary GraphQL. Handlers land in M1, M6, M7;
 * until then each validates its input and answers 501.
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

  app.get("/catalog/discover", (c) => {
    const q = check(c, discoverQuery, c.req.query());
    return q.ok ? notYet(c) : q.res;
  });

  app.get("/catalog/title/:provider/:id", (c) => {
    const p = check(c, titleParams, c.req.param());
    return p.ok ? notYet(c) : p.res;
  });

  app.get("/catalog/search", (c) => {
    const q = check(c, searchQuery, c.req.query());
    return q.ok ? notYet(c) : q.res;
  });

  app.get("/catalog/providers/:tmdbId", (c) => {
    const p = check(c, providersParams, c.req.param());
    if (!p.ok) return p.res;
    const q = check(c, providersQuery, c.req.query());
    return q.ok ? notYet(c) : q.res;
  });

  app.get("/catalog/image", (c) => {
    const q = check(c, imageQuery, c.req.query());
    return q.ok ? notYet(c) : q.res;
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
    // Error class only; messages can carry request data.
    console.error(JSON.stringify({ e: err.name, r: c.req.routePath }));
    return fail(c, 500, "internal");
  });

  return app;
}
