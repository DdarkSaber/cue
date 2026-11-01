import { diagnosticEvent, type DiagnosticEvent } from "./schemas";

export const DIAGNOSTICS_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;
export const DIAGNOSTICS_WRITE_INTERVAL_MS = 5000;
export const MAX_DIAGNOSTICS_EVENTS = 100;
export const MAX_DIAGNOSTICS_SESSIONS = 1000;

interface Row {
  events: string;
  revision: number;
  last_write_at: number;
  expires_at: number;
}

type StoredEvent = DiagnosticEvent & { receivedAt: number };
export type AppendResult =
  | { ok: true; accepted: number }
  | { ok: false; reason: "rate_limited" | "quota_exceeded" };

/** The capability digest is the primary key: no bearer token is persisted. */
export class DiagnosticsStore {
  constructor(private readonly db: D1Database) {}

  private async run(sql: string, ...values: (string | number)[]) {
    const result = await this.db.prepare(sql).bind(...values).run();
    if (!result.success) throw new Error("DiagnosticsStorageUnavailable");
    return result.meta.changes ?? 0;
  }

  private async row(id: string): Promise<Row | null> {
    const result = await this.db.prepare(
      "SELECT events, revision, last_write_at, expires_at FROM diagnostic_sessions WHERE id = ?",
    ).bind(id).all<Row>();
    if (!result.success) throw new Error("DiagnosticsStorageUnavailable");
    return result.results[0] ?? null;
  }

  private events(row: Row): StoredEvent[] {
    const parsed: unknown = JSON.parse(row.events);
    if (!Array.isArray(parsed) || parsed.length > MAX_DIAGNOSTICS_EVENTS) {
      throw new Error("DiagnosticsStorageUnavailable");
    }
    return parsed.map((value: unknown) => {
      if (!value || typeof value !== "object" || !("receivedAt" in value)) {
        throw new Error("DiagnosticsStorageUnavailable");
      }
      const { receivedAt, ...event } = value;
      if (typeof receivedAt !== "number" || !Number.isSafeInteger(receivedAt)) {
        throw new Error("DiagnosticsStorageUnavailable");
      }
      return { ...diagnosticEvent.parse(event), receivedAt };
    });
  }

  /** At most 25 expired sessions plus the requested expired session per call. */
  async prune(id: string, now: number): Promise<void> {
    await this.run(
      `DELETE FROM diagnostic_sessions WHERE id IN
       (SELECT id FROM diagnostic_sessions WHERE expires_at <= ? ORDER BY expires_at LIMIT 25)
       OR (id = ? AND expires_at <= ?)`,
      now, id, now,
    );
  }

  async get(id: string, now: number): Promise<DiagnosticEvent[] | null> {
    await this.prune(id, now);
    const row = await this.row(id);
    if (!row || row.expires_at <= now) return null;
    return this.events(row)
      .filter((event) => event.receivedAt > now - DIAGNOSTICS_MAX_AGE_MS)
      .map(({ receivedAt: _receivedAt, ...event }) => event);
  }

  async append(id: string, batch: DiagnosticEvent[], now: number): Promise<AppendResult> {
    await this.prune(id, now);
    // A single conditional INSERT serializes the global quota in SQLite.
    // Existing sessions use revision CAS; a failed CAS always rereads.
    for (let attempt = 0; attempt < 5; attempt++) {
      const row = await this.row(id);
      const existing = row ? this.events(row) : [];
      const ids = new Set(existing.map((event) => event.requestId));
      const added = batch.filter((event) => {
        if (ids.has(event.requestId)) return false;
        ids.add(event.requestId);
        return true;
      });
      if (added.length === 0) return { ok: true, accepted: 0 };
      if (row && now - row.last_write_at < DIAGNOSTICS_WRITE_INTERVAL_MS) {
        return { ok: false, reason: "rate_limited" };
      }
      if (existing.length + added.length > MAX_DIAGNOSTICS_EVENTS) {
        return { ok: false, reason: "quota_exceeded" };
      }
      const events = JSON.stringify([
        ...existing, ...added.map((event) => ({ ...event, receivedAt: now })),
      ]);
      if (!row) {
        const changed = await this.run(
          `INSERT INTO diagnostic_sessions (id, events, revision, last_write_at, expires_at)
           SELECT ?, ?, 1, ?, ? WHERE (SELECT COUNT(*) FROM diagnostic_sessions) < ?
           ON CONFLICT(id) DO NOTHING`,
          id, events, now, now + DIAGNOSTICS_MAX_AGE_MS, MAX_DIAGNOSTICS_SESSIONS,
        );
        if (changed === 1) return { ok: true, accepted: added.length };
        if (!(await this.row(id))) return { ok: false, reason: "quota_exceeded" };
      } else {
        const changed = await this.run(
          `UPDATE diagnostic_sessions SET events = ?, revision = revision + 1, last_write_at = ?
           WHERE id = ? AND revision = ? AND expires_at = ? AND expires_at > ?`,
          events, now, id, row.revision, row.expires_at, now,
        );
        if (changed === 1) return { ok: true, accepted: added.length };
      }
    }
    return { ok: false, reason: "rate_limited" };
  }
}
