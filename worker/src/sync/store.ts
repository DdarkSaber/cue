/**
 * Encrypted sync blobs. The Worker never sees plaintext or keys: devices
 * encrypt before upload and authenticate with a token derived from the
 * sync code. Only a SHA-256 of that token is stored.
 */
export const MAX_SYNC_BYTES = 2 * 1024 * 1024;

/** Encrypted copies untouched this long are abandoned. */
export const SYNC_MAX_AGE_MS = 180 * 24 * 60 * 60 * 1000;

export interface SyncBlob {
  version: number;
  data: string;
  updatedAt: number;
}

export type PutResult =
  | { ok: true; version: number }
  | { ok: false; reason: "conflict"; version: number }
  | { ok: false; reason: "forbidden" | "not_found" };

export const SCHEMA = `CREATE TABLE IF NOT EXISTS sync_blobs (
  id TEXT PRIMARY KEY,
  token_hash TEXT NOT NULL,
  version INTEGER NOT NULL,
  data TEXT NOT NULL,
  updated_at INTEGER NOT NULL
)`;

export async function sha256Hex(s: string): Promise<string> {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Constant-time comparison of two hex digests of equal length. */
export function same(a: string, b: string) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export class SyncStore {
  constructor(private readonly db: D1Database) {}

  /** Deletes copies nobody has written for [maxAgeMs]; returns how many. */
  async prune(now: number, maxAgeMs: number): Promise<number> {
    const res = await this.db
      .prepare("DELETE FROM sync_blobs WHERE updated_at < ?")
      .bind(now - maxAgeMs)
      .run();
    return res.meta.changes ?? 0;
  }

  private async row(id: string) {
    return this.db
      .prepare("SELECT token_hash, version, data, updated_at FROM sync_blobs WHERE id = ?")
      .bind(id)
      .first<{ token_hash: string; version: number; data: string; updated_at: number }>();
  }

  async get(id: string, token: string): Promise<SyncBlob | "forbidden" | null> {
    const r = await this.row(id);
    if (!r) return null;
    if (!same(r.token_hash, await sha256Hex(token))) return "forbidden";
    return { version: r.version, data: r.data, updatedAt: r.updated_at };
  }

  /** Writes when `expected` matches the stored version (0 creates). */
  async put(id: string, token: string, expected: number, data: string, now: number): Promise<PutResult> {
    const hash = await sha256Hex(token);
    if (expected === 0) {
      const res = await this.db
        .prepare(
          "INSERT INTO sync_blobs (id, token_hash, version, data, updated_at) VALUES (?, ?, 1, ?, ?) ON CONFLICT(id) DO NOTHING",
        )
        .bind(id, hash, data, now)
        .run();
      if (res.meta.changes === 1) return { ok: true, version: 1 };
    } else {
      const res = await this.db
        .prepare(
          "UPDATE sync_blobs SET data = ?, version = version + 1, updated_at = ? WHERE id = ? AND token_hash = ? AND version = ?",
        )
        .bind(data, now, id, hash, expected)
        .run();
      if (res.meta.changes === 1) return { ok: true, version: expected + 1 };
    }
    const r = await this.row(id);
    if (!r) return { ok: false, reason: "not_found" };
    if (!same(r.token_hash, hash)) return { ok: false, reason: "forbidden" };
    return { ok: false, reason: "conflict", version: r.version };
  }

  async delete(id: string, token: string): Promise<"deleted" | "forbidden" | "not_found"> {
    const r = await this.row(id);
    if (!r) return "not_found";
    if (!same(r.token_hash, await sha256Hex(token))) return "forbidden";
    await this.db.prepare("DELETE FROM sync_blobs WHERE id = ?").bind(id).run();
    return "deleted";
  }
}
