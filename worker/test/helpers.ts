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
