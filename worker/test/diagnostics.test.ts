import { env } from "cloudflare:workers";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import migration from "../migrations/0002_diagnostics.sql?raw";
import type { Env } from "../src/env";
import { diagnosticsToken, MAX_DIAGNOSTICS_BYTES, type DiagnosticEvent } from "../src/diagnostics/schemas";
import { DiagnosticsStore, DIAGNOSTICS_MAX_AGE_MS } from "../src/diagnostics/store";
import { SCHEMA, sha256Hex } from "../src/sync/store";
import { APP_ORIGIN, call, fakeEnv, fakeLimiter } from "./helpers";

const now = Date.UTC(2026, 10, 1);
const expiresAt = now + DIAGNOSTICS_MAX_AGE_MS;
let token: string;
let id: string;

function event(): DiagnosticEvent {
  return {
    requestId: crypto.randomUUID(), appVersion: "0.1.0+1", provider: "cue",
    operation: "search", durationMs: 120, status: "ok", errorCode: "none",
  };
}

function request(method: string, body?: unknown, overrides: Partial<Env> = {}, auth = `Bearer ${token}`, path = `/diagnostics/${id}`) {
  return call(path, {
    method,
    headers: { Authorization: auth, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  }, fakeEnv({ SYNC_DB: env.SYNC_DB, ...overrides }));
}

function create(body: unknown = { events: [event()] }, overrides: Partial<Env> = {}, headers: Record<string, string> = {}, path = "/diagnostics") {
  return call(path, {
    method: "POST", headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body),
  }, fakeEnv({ SYNC_DB: env.SYNC_DB, ...overrides }));
}

async function session(events = [event()]) {
  const response = await create({ events });
  expect(response.status).toBe(200);
  const result = await response.json() as { token: string; accepted: number; expiresAt: number };
  token = result.token;
  id = await sha256Hex(token);
  return result;
}

beforeEach(async () => {
  for (const statement of migration.replace(/--[^\n]*/g, "").split(";").filter((s) => s.trim())) {
    await env.SYNC_DB.prepare(statement).run();
  }
  await env.SYNC_DB.prepare("DELETE FROM diagnostic_sessions").run();
  token = "A".repeat(43);
  id = await sha256Hex(token);
  vi.spyOn(Date, "now").mockReturnValue(now);
});
afterEach(() => vi.restoreAllMocks());

describe("server-issued capabilities", () => {
  it("creates the first batch and returns only a canonical capability, count and fixed expiry", async () => {
    const item = event();
    const result = await session([item, { ...item, durationMs: 42 }]);
    expect(Object.keys(result).sort()).toEqual(["accepted", "expiresAt", "token"]);
    expect(result.accepted).toBe(1);
    expect(result.expiresAt).toBe(expiresAt);
    expect(diagnosticsToken(`Bearer ${result.token}`)).toBe(result.token);
    expect(result.token).not.toBe("A".repeat(43));
    expect(await (await request("GET")).json()).toEqual({ events: [item] });
    const other = await create();
    const next = await other.json() as { token: string };
    expect(next.token).not.toBe(result.token);
  });

  it.each(["", "Bearer synthetic", "Basic synthetic"])("rejects any Authorization header on POST (%s)", async (auth) => {
    const response = await create(undefined, {}, { Authorization: auth });
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid_request" });
  });

  it("rejects caller-chosen capabilities, IDs, expiry and query parameters", async () => {
    for (const field of ["token", "id", "expiresAt", "accepted"]) {
      expect((await create({ events: [event()], [field]: "synthetic" })).status).toBe(400);
    }
    expect((await create(undefined, {}, {}, "/diagnostics?token=synthetic")).status).toBe(400);
    expect((await request("POST", { events: [event()] })).status).toBe(404);
    expect((await request("PUT", { events: [event()] })).status).toBe(404);
  });

  it("requires a canonical token and matching SHA256 ID for both authenticated methods", async () => {
    await session();
    const other = await sha256Hex("synthetic-other");
    for (const method of ["GET", "PUT"]) {
      for (const auth of ["", "Basic synthetic", "Bearer short", `Bearer ${token}=`, `Bearer ${token}x`, `Bearer ${token.slice(0, 42)}B`]) {
        expect((await request(method, method === "PUT" ? { events: [event()] } : undefined, {}, auth)).status).toBe(403);
      }
      expect((await request(method, undefined, {}, `Bearer ${token}`, `/diagnostics/${other}`)).status).toBe(403);
      expect((await request(method, undefined, {}, `Bearer ${token}`, "/diagnostics/not-hex")).status).toBe(403);
    }
    expect((await request("GET")).status).toBe(200);
  });

  it("does not confuse CORS with auth and has no DELETE route", async () => {
    await session();
    expect((await call(`/diagnostics/${id}`, { headers: { Origin: APP_ORIGIN } },
      fakeEnv({ SYNC_DB: env.SYNC_DB }))).status).toBe(403);
    const preflight = await call("/diagnostics", {
      method: "OPTIONS", headers: { Origin: APP_ORIGIN, "Access-Control-Request-Method": "POST" },
    }, fakeEnv({ SYNC_DB: env.SYNC_DB }));
    expect(preflight.status).toBe(204);
    expect(preflight.headers.get("Access-Control-Allow-Methods")).toContain("POST");
    expect((await request("DELETE")).status).toBe(404);
  });
});

describe("strict technical-only payloads", () => {
  it("accepts mood timing/status and returns no server metadata on GET", async () => {
    const item: DiagnosticEvent = { ...event(), operation: "mood", status: "failed", errorCode: "http_5xx" };
    await session([item]);
    expect(await (await request("GET")).json()).toEqual({ events: [item] });
  });

  it.each(["title", "query", "url", "message", "token", "timestamp", "file", "history", "userId", "email",
    "phrase", "text", "requestBody", "responseBody", "providerKey", "rawError", "synthetic-private-field"])(
    "rejects %s on create and append without echo", async (field) => {
      await session();
      for (const body of [
        { events: [event()], [field]: "synthetic-private-value" },
        { events: [{ ...event(), operation: "mood", [field]: "synthetic-private-value" }] },
      ]) {
        for (const result of [await create(body), await request("PUT", body)]) {
          expect(result.status).toBe(400);
          expect(await result.json()).toEqual({ error: "invalid_request" });
        }
      }
    },
  );

  it.each([
    ["requestId", "synthetic-title"], ["requestId", "00000000-0000-1000-8000-000000000000"],
    ["appVersion", "https://example.invalid"], ["appVersion", "0.1.0+synthetic"], ["appVersion", "1".repeat(33)],
    ["provider", "groq"], ["provider", "gemini"], ["operation", "synthetic-query"],
    ["durationMs", -1], ["durationMs", 120001], ["durationMs", 1.5], ["durationMs", "100"],
    ["status", "raw-error"], ["errorCode", { message: "synthetic" }],
  ])("rejects invalid %s", async (field, value) => {
    const body = { events: [{ ...event(), [field]: value }] };
    expect((await create(body)).status).toBe(400);
    expect((await request("PUT", body)).status).toBe(400);
  });

  it("requires all fields and 1..20 events; query parameters are rejected", async () => {
    for (const field of Object.keys(event())) {
      const incomplete = { ...event() } as Record<string, unknown>;
      delete incomplete[field];
      expect((await create({ events: [incomplete] })).status).toBe(400);
    }
    for (const body of [{}, { events: [] }, { events: Array.from({ length: 21 }, event) }, { events: null }]) {
      expect((await create(body)).status).toBe(400);
      expect((await request("PUT", body)).status).toBe(400);
    }
    const batch = Array.from({ length: 20 }, event);
    await session(batch);
    expect(await (await request("GET")).json()).toEqual({ events: batch });
    for (const method of ["GET", "PUT"]) {
      expect((await request(method, method === "PUT" ? { events: [event()] } : undefined,
        {}, `Bearer ${token}`, `/diagnostics/${id}?query=synthetic`)).status).toBe(400);
    }
  });

  it.each(["POST", "PUT"])("caps %s at actual 6 KiB including streamed and misdeclared bodies", async (method) => {
    const payload = JSON.stringify({ events: [event()], pad: "x".repeat(MAX_DIAGNOSTICS_BYTES) });
    const path = method === "POST" ? "/diagnostics" : `/diagnostics/${id}`;
    for (const mode of ["normal", "stream", "misdeclared"]) {
      const response = await call(path, {
        method,
        headers: {
          "Content-Type": "application/json",
          ...(method === "PUT" ? { Authorization: `Bearer ${token}` } : {}),
          ...(mode === "misdeclared" ? { "Content-Length": "1" } : {}),
        },
        body: mode === "stream" ? new ReadableStream({
          start(controller) { controller.enqueue(new TextEncoder().encode(payload)); controller.close(); },
        }) : payload,
        // @ts-expect-error Node/undici streamed request option.
        duplex: "half",
      }, fakeEnv({ SYNC_DB: env.SYNC_DB }));
      expect(response.status).toBe(413);
    }
  });

  it.each(["POST", "PUT"])("rejects invalid JSON and non-JSON %s", async (method) => {
    for (const [type, body] of [["application/json", "{"], ["text/plain", JSON.stringify({ events: [event()] })]]) {
      expect((await call(method === "POST" ? "/diagnostics" : `/diagnostics/${id}`, {
        method, headers: { "Content-Type": type!, ...(method === "PUT" ? { Authorization: `Bearer ${token}` } : {}) }, body,
      }, fakeEnv({ SYNC_DB: env.SYNC_DB }))).status).toBe(400);
    }
  });

  it("never persists raw capabilities or logs capabilities, IDs, payloads or unknown field names", async () => {
    const lines: string[] = [];
    vi.spyOn(console, "log").mockImplementation((line: unknown) => lines.push(String(line)));
    vi.spyOn(console, "error").mockImplementation((line: unknown) => lines.push(String(line)));
    const fetch = vi.spyOn(globalThis, "fetch");
    const item = event();
    await session([item]);
    const row = await env.SYNC_DB.prepare("SELECT * FROM diagnostic_sessions WHERE id = ?").bind(id).first();
    expect(JSON.stringify(row)).not.toContain(token);
    expect(row).toMatchObject({ id, expires_at: expiresAt });
    const response = await request("GET");
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(await response.json()).toEqual({ events: [item] });
    await create({ events: [item], "synthetic-private-key": "synthetic-private-value" });
    await request("GET", undefined, {}, "Bearer synthetic-invalid");
    await request("DELETE");
    for (const value of [token, id, item.requestId, "synthetic"]) expect(lines.join("\n")).not.toContain(value);
    expect(fetch).not.toHaveBeenCalled();
  });
});

describe("bounded retention, quotas and CAS", () => {
  it("deduplicates first batch and retries, returns fixed expiry and enforces 5 seconds", async () => {
    const item = event();
    await session([item, item]);
    expect(await (await request("PUT", { events: [{ ...item, requestId: item.requestId.toUpperCase() }] })).json())
      .toEqual({ accepted: 0, expiresAt });
    const limited = await request("PUT", { events: [event()] });
    expect(limited.status).toBe(429);
    expect(await limited.json()).toEqual({ error: "rate_limited" });
    expect(limited.headers.get("Retry-After")).toBe("5");
    vi.mocked(Date.now).mockReturnValue(now + 5000);
    expect(await (await request("PUT", { events: [item, event()] })).json()).toEqual({ accepted: 1, expiresAt });
  });

  it("keeps the existing per-IP limiter on creation and append", async () => {
    const limiter = fakeLimiter(1);
    expect((await create(undefined, { RATE_LIMITER: limiter })).status).toBe(200);
    const limited = await create(undefined, { RATE_LIMITER: limiter });
    expect(limited.status).toBe(429);
    expect(limited.headers.get("Retry-After")).toBe("60");
    expect(limiter.keys).toEqual(["unknown", "unknown"]);
    expect((await request("PUT", { events: [event()] }, { RATE_LIMITER: limiter })).status).toBe(429);
    expect((await create(undefined, { RATE_LIMITER: undefined as unknown as RateLimit })).status).toBe(503);
  });

  it("rejects whole batches above 100 events without evicting earlier events", async () => {
    const batch = Array.from({ length: 20 }, event);
    await session(batch);
    const store = new DiagnosticsStore(env.SYNC_DB);
    for (let i = 1; i < 5; i++) {
      expect(await store.append(id, Array.from({ length: 20 }, event), now + i * 5000))
        .toEqual({ ok: true, accepted: 20, expiresAt });
    }
    vi.mocked(Date.now).mockReturnValue(now + 25000);
    const response = await request("PUT", { events: [event()] });
    expect(response.status).toBe(429);
    expect(await response.json()).toEqual({ error: "quota_exceeded" });
    expect(await store.append(id, batch, now + 25000)).toEqual({ ok: true, accepted: 0, expiresAt });
    expect((await store.get(id, now + 25000))!.slice(0, 20)).toEqual(batch);
  });

  it("concurrent updates never lose events or bypass the session rate", async () => {
    await session();
    const store = new DiagnosticsStore(env.SYNC_DB);
    const attempts = await Promise.all(Array.from({ length: 10 }, () => store.append(id, [event()], now + 5000)));
    expect(attempts.filter((r) => r.ok)).toHaveLength(1);
    expect(attempts.filter((r) => !r.ok && r.reason === "rate_limited")).toHaveLength(9);
    expect(await store.get(id, now + 5000)).toHaveLength(2);
  });

  it("concurrent retries are idempotent", async () => {
    const batch = [event()];
    await session(batch);
    const store = new DiagnosticsStore(env.SYNC_DB);
    const results = await Promise.all(Array.from({ length: 10 }, () => store.append(id, batch, now)));
    expect(results).toEqual(Array(10).fill({ ok: true, accepted: 0, expiresAt }));
    expect(await store.get(id, now)).toEqual(batch);
  });

  it("cannot race past the per-session event cap", async () => {
    await session();
    const store = new DiagnosticsStore(env.SYNC_DB);
    await env.SYNC_DB.prepare("UPDATE diagnostic_sessions SET events = ? WHERE id = ?")
      .bind(JSON.stringify(Array.from({ length: 99 }, () => ({ ...event(), receivedAt: now }))), id).run();
    const results = await Promise.all(Array.from({ length: 10 }, (_, i) =>
      store.append(id, Array.from({ length: i % 2 + 1 }, event), now + 5000)));
    expect(results.filter((r) => r.ok)).toHaveLength(1);
    expect(await store.get(id, now + 5000)).toHaveLength(100);
  });

  it("conditional server-issued creation cannot race past the global 1000 cap", async () => {
    await env.SYNC_DB.prepare(
      `WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<999)
       INSERT INTO diagnostic_sessions (id, events, revision, last_write_at, expires_at)
       SELECT printf('%064x', x), '[]', 1, ?, ? FROM n`,
    ).bind(now, expiresAt).run();
    const store = new DiagnosticsStore(env.SYNC_DB);
    const results = await Promise.all(Array.from({ length: 10 }, () => store.create([event()], now)));
    expect(results.filter((r) => r.ok)).toHaveLength(1);
    expect(results.filter((r) => !r.ok && r.reason === "quota_exceeded")).toHaveLength(9);
    expect((await create()).status).toBe(429);
    const count = await env.SYNC_DB.prepare("SELECT COUNT(*) AS n FROM diagnostic_sessions").first<{ n: number }>();
    expect(count!.n).toBe(1000);
    const winner = results.find((r) => r.ok)!;
    if (!winner.ok) throw new Error("Missing synthetic creation");
    expect(await store.append(await sha256Hex(winner.token), [event()], now + 5000))
      .toEqual({ ok: true, accepted: 1, expiresAt });
  });

  it("expires exactly at seven days; duplicate and new writes never recreate before/after pruning", async () => {
    const item = event();
    await session([item]);
    const oldToken = token;
    const oldId = id;
    const store = new DiagnosticsStore(env.SYNC_DB);
    expect(await store.append(id, [item], expiresAt - 1)).toEqual({ ok: true, accepted: 0, expiresAt });
    expect(await store.append(id, [event()], expiresAt - 1)).toEqual({ ok: true, accepted: 1, expiresAt });
    vi.mocked(Date.now).mockReturnValue(expiresAt);
    for (const batch of [[item], [event()]]) {
      const response = await request("PUT", { events: batch });
      expect(response.status).toBe(404);
      expect(await response.json()).toEqual({ error: "not_found" });
    }
    expect((await request("GET")).status).toBe(404);
    expect(await env.SYNC_DB.prepare("SELECT id FROM diagnostic_sessions WHERE id = ?").bind(id).first()).toBeNull();
    await session();
    expect(token).not.toBe(oldToken);
    expect(id).not.toBe(oldId);
    for (const method of ["GET", "PUT"]) {
      expect((await request(method, method === "PUT" ? { events: [event()] } : undefined,
        {}, `Bearer ${oldToken}`, `/diagnostics/${oldId}`)).status).toBe(404);
    }
    expect(await store.append(oldId, [item], expiresAt + 5000)).toEqual({ ok: false, reason: "not_found" });
  });

  it("missing and explicitly pruned/deleted sessions never allow PUT creation", async () => {
    expect((await request("PUT", { events: [event()] })).status).toBe(404);
    await session();
    await env.SYNC_DB.prepare("DELETE FROM diagnostic_sessions WHERE id = ?").bind(id).run();
    const responses = await Promise.all(Array.from({ length: 10 }, () => request("PUT", { events: [event()] })));
    expect(responses.every((response) => response.status === 404)).toBe(true);
    expect(await env.SYNC_DB.prepare("SELECT id FROM diagnostic_sessions").first()).toBeNull();
  });

  it("lost creation responses leave separate bounded sessions, never reusing an old capability", async () => {
    await session();
    const lostToken = token;
    const oldId = id;
    await session();
    expect(token).not.toBe(lostToken);
    expect(id).not.toBe(oldId);
    const rows = await env.SYNC_DB.prepare("SELECT COUNT(*) AS n FROM diagnostic_sessions").first<{ n: number }>();
    expect(rows!.n).toBe(2);
    await new DiagnosticsStore(env.SYNC_DB).prune(oldId, expiresAt);
    expect(await env.SYNC_DB.prepare("SELECT id FROM diagnostic_sessions").first()).toBeNull();
  });

  it("CAS cannot resurrect a row pruned between reading and writing", async () => {
    await session();
    const store = new DiagnosticsStore(env.SYNC_DB);
    let pruned = false;
    const db = {
      prepare(sql: string) {
        const statement = env.SYNC_DB.prepare(sql);
        if (!sql.startsWith("UPDATE")) return statement;
        return { bind(...values: unknown[]) {
          const bound = statement.bind(...values);
          return { async run() {
            if (!pruned) { pruned = true; await store.prune(id, expiresAt); }
            return bound.run();
          } };
        } };
      },
    } as D1Database;
    expect(await new DiagnosticsStore(db).append(id, [event()], now + 5000))
      .toEqual({ ok: false, reason: "not_found" });
    expect(await env.SYNC_DB.prepare("SELECT id FROM diagnostic_sessions WHERE id = ?").bind(id).first()).toBeNull();
  });

  it("prunes bounded expired rows on creation and leaves sync untouched", async () => {
    await env.SYNC_DB.prepare(SCHEMA).run();
    await env.SYNC_DB.prepare(
      "INSERT INTO sync_blobs (id, token_hash, version, data, updated_at) VALUES ('synthetic-sync', 'h', 1, 'synthetic', 0)",
    ).run();
    await env.SYNC_DB.prepare(
      `WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<60)
       INSERT INTO diagnostic_sessions (id, events, revision, last_write_at, expires_at)
       SELECT printf('%064x', x), '[]', 1, 0, ? FROM n`,
    ).bind(now).run();
    await session();
    const count = await env.SYNC_DB.prepare("SELECT COUNT(*) AS n FROM diagnostic_sessions WHERE expires_at <= ?")
      .bind(now).first<{ n: number }>();
    expect(count!.n).toBe(35);
    expect(await new DiagnosticsStore(env.SYNC_DB).get(id, now)).toHaveLength(1);
    expect(await env.SYNC_DB.prepare("SELECT data FROM sync_blobs WHERE id = 'synthetic-sync'").first())
      .toEqual({ data: "synthetic" });
  });
});

describe("explicit storage failures", () => {
  it("returns 503 for missing binding and unapplied migration on every method", async () => {
    expect((await create(undefined, { SYNC_DB: undefined as unknown as D1Database })).status).toBe(503);
    for (const method of ["GET", "PUT"]) {
      expect((await request(method, method === "PUT" ? { events: [event()] } : undefined,
        { SYNC_DB: undefined as unknown as D1Database })).status).toBe(503);
    }
    await env.SYNC_DB.prepare("DROP TABLE diagnostic_sessions").run();
    for (const response of [await create(), await request("GET"), await request("PUT", { events: [event()] })]) {
      expect(response.status).toBe(503);
      expect(await response.json()).toEqual({ error: "unavailable" });
    }
  });

  it("never reports success for failed create/update operations", async () => {
    await session();
    const broken = {
      prepare(sql: string) {
        if (sql.startsWith("INSERT") || sql.startsWith("UPDATE")) throw new Error("synthetic storage failure");
        return env.SYNC_DB.prepare(sql);
      },
    } as D1Database;
    vi.mocked(Date.now).mockReturnValue(now + 5000);
    for (const response of [await create(undefined, { SYNC_DB: broken }),
      await request("PUT", { events: [event()] }, { SYNC_DB: broken })]) {
      expect(response.status).toBe(503);
      expect(await response.json()).toEqual({ error: "unavailable" });
    }
  });

  it("fails closed on a generated capability collision without returning an existing token", async () => {
    vi.spyOn(crypto, "getRandomValues").mockImplementation((array) => array);
    await create();
    const response = await create();
    expect(response.status).toBe(429);
    expect(await response.json()).toEqual({ error: "quota_exceeded" });
  });

  it("does not leak unknown/corrupt stored event fields on GET", async () => {
    await session();
    await env.SYNC_DB.prepare("UPDATE diagnostic_sessions SET events = ? WHERE id = ?")
      .bind(JSON.stringify([{ ...event(), receivedAt: now, title: "synthetic-private" }]), id).run();
    const response = await request("GET");
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: "unavailable" });
  });

  it("treats unsuccessful D1 result flags as failure rather than successful creation or append", async () => {
    const db = {
      prepare() {
        return {
          bind() { return this; },
          async run() { return { success: false, meta: { changes: 1 } }; },
        };
      },
    } as unknown as D1Database;
    for (const response of [await create(undefined, { SYNC_DB: db }),
      await request("PUT", { events: [event()] }, { SYNC_DB: db })]) {
      expect(response.status).toBe(503);
      expect(await response.json()).toEqual({ error: "unavailable" });
    }
  });
});
