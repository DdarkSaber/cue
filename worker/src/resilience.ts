/**
 * Small, dependency-free resilience helpers: a per-isolate circuit breaker,
 * jittered backoff, Retry-After parsing and in-flight request sharing.
 * State lives in the isolate only (no KV/DO); it is a best-effort guard that
 * stops hammering a provider that is clearly down, not a global guarantee.
 */

export const BREAKER_THRESHOLD = 5;
export const BREAKER_OPEN_MS = 30_000;

interface Circuit {
  fails: number;
  openUntil: number;
}
const circuits = new Map<string, Circuit>();

/** True while the circuit for `name` is open (fast-fail, no upstream call). */
export function isOpen(name: string, now = Date.now()): boolean {
  const c = circuits.get(name);
  return Boolean(c && c.openUntil > now);
}

export function recordSuccess(name: string) {
  circuits.delete(name);
}

/**
 * Counts a provider-side failure (network, timeout, 5xx, 429); opens at the
 * threshold. After the open window lapses one probe passes ("half-open"); the
 * failure count is kept, so a failed probe re-opens the circuit immediately.
 */
export function recordFailure(name: string, now = Date.now()) {
  const c = circuits.get(name) ?? { fails: 0, openUntil: 0 };
  c.fails += 1;
  if (c.fails >= BREAKER_THRESHOLD) c.openUntil = now + BREAKER_OPEN_MS;
  circuits.set(name, c);
}

export function resetBreakers() {
  circuits.clear();
}

/** Retry-After in ms (seconds or HTTP date), capped; null when absent/invalid. */
export function retryAfterMs(header: string | null, capMs: number, now = Date.now()): number | null {
  if (!header) return null;
  const secs = Number(header);
  const ms = Number.isFinite(secs) ? secs * 1000 : Date.parse(header) - now;
  if (!Number.isFinite(ms) || ms < 0) return null;
  return Math.min(ms, capMs);
}

/** Full-jitter exponential backoff: random in [0, base * 2^attempt], capped. */
export function backoffMs(attempt: number, baseMs = 250, capMs = 2000, rand = Math.random): number {
  return Math.floor(rand() * Math.min(capMs, baseMs * 2 ** attempt));
}

export const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

const inflight = new Map<string, Promise<unknown>>();

/** Concurrent callers with the same key share one in-flight promise (stampede guard). */
export function shared<T>(key: string, run: () => Promise<T>): Promise<T> {
  const existing = inflight.get(key);
  if (existing) return existing as Promise<T>;
  const p = run().finally(() => inflight.delete(key));
  inflight.set(key, p);
  return p;
}
