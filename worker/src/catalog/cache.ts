/** Cache lifetimes for public catalog data. */
export const TTL = {
  discover: 24 * 60 * 60,
  search: 24 * 60 * 60,
  title: 7 * 24 * 60 * 60,
  providers: 24 * 60 * 60,
} as const;

const PREFIX = "v1:";

/**
 * Read-through KV cache for public catalog responses only. A KV failure
 * (including the free tier's daily write cap) degrades to a live fetch.
 */
export async function cached<T>(
  kv: KVNamespace | undefined,
  key: string,
  ttl: number,
  load: () => Promise<T>,
): Promise<{ value: T; hit: boolean }> {
  const fullKey = PREFIX + key;
  if (kv && typeof kv.get === "function") {
    try {
      const hit = await kv.get<T>(fullKey, "json");
      if (hit !== null) return { value: hit, hit: true };
    } catch {
      // Fall through to a live fetch.
    }
  }
  const value = await load();
  if (kv && typeof kv.put === "function" && value !== null) {
    try {
      await kv.put(fullKey, JSON.stringify(value), { expirationTtl: ttl });
    } catch {
      // Over the write quota: serve uncached.
    }
  }
  return { value, hit: false };
}
