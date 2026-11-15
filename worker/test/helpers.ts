import { env as workerEnv } from "cloudflare:workers";

import { createApp } from "../src/app";
import type { Env } from "../src/env";

export const APP_ORIGIN = "http://localhost:7357";

/** A rate limiter that allows `budget` calls per key, then refuses. */
export function fakeLimiter(budget = 1000): RateLimit & { keys: string[] } {
  const used = new Map<string, number>();
  const keys: string[] = [];
  return {
    keys,
    async limit({ key }) {
      keys.push(key);
      const n = (used.get(key) ?? 0) + 1;
      used.set(key, n);
      return { success: n <= budget };
    },
  };
}

export function fakeEnv(overrides: Partial<Env> = {}): Env {
  return {
    CATALOG_CACHE: {} as KVNamespace,
    RATE_LIMITER: fakeLimiter(),
    IMAGE_LIMITER: fakeLimiter(),
    SYNC_DB: undefined as unknown as D1Database,
    ALLOWED_ORIGINS: `${APP_ORIGIN},http://127.0.0.1:7357`,
    ...overrides,
  };
}

export function call(
  path: string,
  init: RequestInit = {},
  env: Env = fakeEnv(),
) {
  return createApp().request(`https://api.test${path}`, init, env);
}

export function postJson(path: string, body: unknown, env?: Env) {
  return call(
    path,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    },
    env,
  );
}

type Upstream = (url: URL, init?: RequestInit) => Response | Promise<Response>;

/** Empty but well-formed provider answers, so routes run without network. */
export const emptyUpstream: Upstream = (url) => {
  const json = (body: unknown) =>
    new Response(JSON.stringify(body), {
      headers: { "Content-Type": "application/json" },
    });
  switch (url.hostname) {
    case "api.tvmaze.com":
      // Page listings are arrays; page 0 exists, later pages do not.
      return url.pathname === "/shows" && Number(url.searchParams.get("page")) > 0
        ? new Response(null, { status: 404 })
        : json([]);
    case "cinemeta-catalogs.strem.io":
    case "v3-cinemeta.strem.io":
      return json({ metas: [] });
    case "api.themoviedb.org":
      return json({ page: 1, total_pages: 1, results: [] });
    default:
      return new Response(new Uint8Array([137, 80, 78, 71]), {
        headers: { "Content-Type": "image/png" },
      });
  }
};

/** Replaces global fetch; returns the URLs the Worker asked for. */
export function mockUpstream(
  vi: { spyOn: typeof import("vitest").vi.spyOn },
  handler: Upstream = emptyUpstream,
) {
  const calls: { url: URL; init?: RequestInit }[] = [];
  vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
    const url = new URL(input instanceof Request ? input.url : String(input));
    calls.push({ url, init });
    return handler(url, init);
  });
  return calls;
}

/** In-memory KV with the subset of the API the cache uses. */
export function fakeKv() {
  const store = new Map<string, string>();
  const kv = {
    store,
    async get(key: string, type?: string) {
      const v = store.get(key);
      if (v === undefined) return null;
      return type === "json" ? JSON.parse(v) : v;
    },
    async put(key: string, value: string) {
      store.set(key, value);
    },
  };
  return kv as unknown as KVNamespace & { store: Map<string, string> };
}

/** An env for /ai routes: a key, an in-memory cache and the local D1 for the daily counters. */
export function aiEnv(overrides: Partial<Env> = {}): Env {
  return fakeEnv({ GROQ_API_KEY: "k", CATALOG_CACHE: fakeKv(), SYNC_DB: workerEnv.SYNC_DB, ...overrides });
}
