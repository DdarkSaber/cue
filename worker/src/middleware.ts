import type { MiddlewareHandler } from "hono";
import { bodyLimit } from "hono/body-limit";
import { cors } from "hono/cors";
import { secureHeaders } from "hono/secure-headers";

import type { AppEnv } from "./env";
import { fail } from "./errors";
import { MAX_SYNC_BYTES } from "./sync/store";
import { MAX_DIAGNOSTICS_BYTES } from "./diagnostics/schemas";

export const MAX_BODY_BYTES = 8 * 1024;

export function allowedOrigins(raw: string | undefined): Set<string> {
  return new Set(
    (raw ?? "")
      .split(",")
      .map((o) => o.trim())
      .filter(Boolean),
  );
}

/**
 * Logs one line per request: method, matched route pattern, status, duration.
 * Never the query string, body, headers or client IP.
 */
export const requestLog: MiddlewareHandler<AppEnv> = async (c, next) => {
  const start = Date.now();
  await next();
  console.log(
    JSON.stringify({
      m: c.req.method,
      r: c.req.routePath,
      s: c.res.status,
      ms: Date.now() - start,
    }),
  );
};

/** Requests from browsers must come from an app origin. Native apps send none. */
export const originGuard: MiddlewareHandler<AppEnv> = async (c, next) => {
  const origin = c.req.header("Origin");
  if (origin && !allowedOrigins(c.env.ALLOWED_ORIGINS).has(origin)) {
    return fail(c, 403, "origin_not_allowed");
  }
  await next();
};

export const corsPolicy: MiddlewareHandler<AppEnv> = (c, next) =>
  cors({
    origin: (origin) =>
      allowedOrigins(c.env.ALLOWED_ORIGINS).has(origin) ? origin : null,
    allowMethods: ["GET", "POST", "PUT", "DELETE"],
    allowHeaders: ["Content-Type", "Authorization"],
    maxAge: 600,
  })(c, next);

const smallBody = bodyLimit({
  maxSize: MAX_BODY_BYTES,
  onError: (c) => fail(c, 413, "payload_too_large"),
});
const syncBodyLimit = bodyLimit({
  maxSize: MAX_SYNC_BYTES,
  onError: (c) => fail(c, 413, "payload_too_large"),
});
const boundedDiagnosticsBody = bodyLimit({
  maxSize: MAX_DIAGNOSTICS_BYTES,
  onError: (c) => fail(c, 413, "payload_too_large"),
});
const diagnosticsBodyLimit: MiddlewareHandler<AppEnv> = (c, next) => {
  // Count actual bytes even if a client supplies an incorrect Content-Length.
  if (c.req.raw.body && c.req.header("Content-Length") !== undefined) {
    const headers = new Headers(c.req.raw.headers);
    headers.delete("Content-Length");
    c.req.raw = new Request(c.req.raw, { headers });
  }
  return boundedDiagnosticsBody(c, next);
};

/** Diagnostics are additionally capped at 6 KB; sync uploads allow 2 MB. */
export const bodyCap: MiddlewareHandler<AppEnv> = (c, next) =>
  c.req.path.startsWith("/sync/") ? syncBodyLimit(c, next)
    : c.req.path.startsWith("/diagnostics/") ? diagnosticsBodyLimit(c, next)
      : smallBody(c, next);

/** Per-IP limit through the Workers rate-limiting binding. Fails closed. */
export const rateLimit: MiddlewareHandler<AppEnv> = async (c, next) => {
  const limiter =
    c.req.path === "/catalog/image"
      ? c.env.IMAGE_LIMITER
      : c.req.path === "/ai/mood"
        ? (c.env.AI_LIMITER ?? c.env.RATE_LIMITER)
        : c.env.RATE_LIMITER;
  if (!limiter) return fail(c, 503, "unavailable");
  const key = c.req.header("CF-Connecting-IP") ?? "unknown";
  const { success } = await limiter.limit({ key });
  if (!success) {
    c.header("Retry-After", "60");
    return fail(c, 429, "rate_limited");
  }
  await next();
};

/** JSON API responses: no sniffing, no framing, no referrer, never cached by shared caches. */
export const apiHeaders: MiddlewareHandler<AppEnv> = async (c, next) => {
  await secureHeaders({
    contentSecurityPolicy: { defaultSrc: ["'none'"], frameAncestors: ["'none'"] },
    crossOriginResourcePolicy: "cross-origin",
    referrerPolicy: "no-referrer",
  })(c, next);
  if (!c.res.headers.has("Cache-Control")) c.header("Cache-Control", "no-store");
};
