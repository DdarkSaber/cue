import { shared } from "../resilience";
import { sha256Hex } from "../sync/store";

/** Cache lifetimes for public catalog data. */
export const TTL = {
  discover: 24 * 60 * 60,
  search: 24 * 60 * 60,
  title: 7 * 24 * 60 * 60,
  providers: 24 * 60 * 60,
} as const;

/** A "not found" or empty answer is remembered only briefly (KV minimum is 60s). */
export const NEGATIVE_TTL = 10 * 60;

const PREFIX = "v1:";
/** KV keys are limited to 512 bytes; longer ones are replaced by a hash. */
const MAX_KEY_BYTES = 400;
const MISS = { $miss: 1 };

const isMiss = (v: unknown) => typeof v === "object" && v !== null && (v as { $miss?: unknown }).$miss === 1;

function isEmpty(v: unknown): boolean {
  if (Array.isArray(v)) return v.length === 0;
  const items = (v as { items?: unknown } | null)?.items;
  return Array.isArray(items) && items.length === 0;
}

async function keyFor(key: string): Promise<string> {
  const full = PREFIX + key;
  return new TextEncoder().encode(full).length <= MAX_KEY_BYTES
    ? full
    : `${PREFIX}h:${(await sha256Hex(full)).slice(0, 48)}`;
}

/**
 * Read-through KV cache for public catalog responses only. A KV failure
 * (including the free tier's daily write cap) degrades to a live fetch.
 * Concurrent misses for one key share a single upstream call. A null or
 * empty answer is cached for minutes, not days, so a transient gap heals.
 * Upstream errors throw and are never cached.
 */
export async function cached<T>(
  kv: KVNamespace | undefined,
  key: string,
  ttl: number,
  load: () => Promise<T>,
): Promise<{ value: T; hit: boolean }> {
  const fullKey = await keyFor(key);
  if (kv && typeof kv.get === "function") {
    try {
      const hit = await kv.get<T>(fullKey, "json");
      if (hit !== null) return { value: (isMiss(hit) ? null : hit) as T, hit: true };
    } catch {
      // Fall through to a live fetch.
    }
  }
  const value = await shared(fullKey, async () => {
    const v = await load();
    if (kv && typeof kv.put === "function") {
      const missing = v === null || v === undefined;
      try {
        await kv.put(fullKey, JSON.stringify(missing ? MISS : v), {
          expirationTtl: missing || isEmpty(v) ? Math.min(ttl, NEGATIVE_TTL) : ttl,
        });
      } catch {
        // Over the write quota: serve uncached.
      }
    }
    return v;
  });
  return { value, hit: false };
}
