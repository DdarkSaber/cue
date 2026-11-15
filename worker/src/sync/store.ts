/**
 * Encrypted sync blobs. The Worker never sees plaintext or keys: devices
 * encrypt before upload and authenticate with a token derived from the
 * sync code. Only a SHA-256 of that token is stored.
 */
/**
 * Request body cap for /sync. D1 refuses a value over ~2 MB with a 500, so the
 * cap sits below that: a too-big upload is a clean 413, never a storage error.
 */
export const MAX_SYNC_BYTES = Math.floor(1.9 * 1024 * 1024);

/**
 * Global caps across all sync copies, so one script cannot fill the shared
 * 500 MB D1 (diagnostics lives there too). Checked inside the write itself.
 */
export const MAX_SYNC_ROWS = 5000;
export const MAX_SYNC_TOTAL_BYTES = 400 * 1000 * 1000;

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
  | { ok: false; reason: "not_found" | "quota_exceeded" };

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
  constructor(
    private readonly db: D1Database,
    // Overridable so tests can reach the caps without writing 400 MB.
    private readonly caps = { rows: MAX_SYNC_ROWS, bytes: MAX_SYNC_TOTAL_BYTES },
  ) {}

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

  /** A wrong token reads as missing, so ids cannot be probed for existence. */
  async get(id: string, token: string): Promise<SyncBlob | null> {
    const r = await this.row(id);
    if (!r || !same(r.token_hash, await sha256Hex(token))) return null;
    return { version: r.version, data: r.data, updatedAt: r.updated_at };
  }

  /**
   * Writes when `expected` matches the stored version (0 creates). Creates
   * stop at the row cap; any write that would push the total past the byte
   * cap is refused. octet_length reads the stored size without loading values.
   */
  async put(id: string, token: string, expected: number, data: string, now: number): Promise<PutResult> {
    const hash = await sha256Hex(token);
    if (expected === 0) {
      const res = await this.db
        .prepare(
          `INSERT INTO sync_blobs (id, token_hash, version, data, updated_at)
           SELECT ?, ?, 1, ?, ?
           WHERE (SELECT COUNT(*) FROM sync_blobs) < ?
             AND (SELECT COALESCE(SUM(octet_length(data)), 0) FROM sync_blobs) + octet_length(?) <= ?
           ON CONFLICT(id) DO NOTHING`,
        )
        .bind(id, hash, data, now, this.caps.rows, data, this.caps.bytes)
        .run();
      if (res.meta.changes === 1) return { ok: true, version: 1 };
    } else {
      // The row's own old size is replaced, so it is not counted twice.
      const res = await this.db
        .prepare(
          `UPDATE sync_blobs SET data = ?, version = version + 1, updated_at = ?
           WHERE id = ? AND token_hash = ? AND version = ?
             AND (SELECT COALESCE(SUM(octet_length(data)), 0) FROM sync_blobs)
                 - octet_length(data) + octet_length(?) <= ?`,
        )
        .bind(data, now, id, hash, expected, data, this.caps.bytes)
        .run();
      if (res.meta.changes === 1) return { ok: true, version: expected + 1 };
    }
    const r = await this.row(id);
    // No row after a refused create: the caps refused it.
    if (!r) return { ok: false, reason: expected === 0 ? "quota_exceeded" : "not_found" };
    if (!same(r.token_hash, hash)) return { ok: false, reason: "not_found" };
    // The right token and version, yet nothing changed: the byte cap refused it.
    if (expected !== 0 && r.version === expected) return { ok: false, reason: "quota_exceeded" };
    return { ok: false, reason: "conflict", version: r.version };
  }

  async delete(id: string, token: string): Promise<"deleted" | "not_found"> {
    const r = await this.row(id);
    if (!r || !same(r.token_hash, await sha256Hex(token))) return "not_found";
    await this.db.prepare("DELETE FROM sync_blobs WHERE id = ?").bind(id).run();
    return "deleted";
  }
}
