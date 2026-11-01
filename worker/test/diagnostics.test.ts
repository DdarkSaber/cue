import { env } from "cloudflare:workers";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import migration from "../migrations/0002_diagnostics.sql?raw";
import { type Env } from "../src/env";
import { diagnosticsBody, diagnosticsToken, MAX_DIAGNOSTICS_BYTES, type DiagnosticEvent } from "../src/diagnostics/schemas";
import { DiagnosticsStore, DIAGNOSTICS_MAX_AGE_MS } from "../src/diagnostics/store";
import { SCHEMA, sha256Hex } from "../src/sync/store";
import { APP_ORIGIN, call, fakeEnv, fakeLimiter } from "./helpers";

const now = Date.UTC(2026, 10, 1);
let token: string;
let id: string;

function event(): DiagnosticEvent {
  return {
    requestId: crypto.randomUUID(),
    appVersion: "0.1.0+1",
    provider: "cue",
    operation: "search",
    durationMs: 120,
    status: "ok",
    errorCode: "none",
  };
}

function request(method: string, body?: unknown, overrides: Partial<Env> = {}, auth = `Bearer ${token}`, path = `/diagnostics/${id}`) {
  return call(path, {
    method,
    headers: { Authorization: auth, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  }, fakeEnv({ SYNC_DB: env.SYNC_DB, ...overrides }));
}

beforeEach(async () => {
  for (const statement of migration.replace(/--[^\n]*/g, "").split(";").filter((s) => s.trim())) {
    await env.SYNC_DB.prepare(statement).run();
  }
  await env.SYNC_DB.prepare("DELETE FROM diagnostic_sessions").run();
  token = btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))))
    .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
  id = await sha256Hex(token);
  vi.spyOn(Date, "now").mockReturnValue(now);
});

afterEach(() => vi.restoreAllMocks());

describe("capability authentication", () => {
  it("requires a canonical 32-byte token and its SHA256 id for both methods", async () => {
    const other = await sha256Hex("another synthetic capability");
    for (const method of ["GET", "PUT"]) {
      for (const auth of ["", "Basic synthetic", "Bearer short", `Bearer ${token}=`, `Bearer ${token}x`, `Bearer ${token.slice(0, 42)}B`]) {
        expect((await request(method, method === "PUT" ? { events: [event()] } : undefined, {}, auth)).status).toBe(403);
      }
      expect((await request(method, method === "PUT" ? { events: [event()] } : undefined, {}, `Bearer ${token}`, `/diagnostics/${other}`)).status).toBe(403);
      expect((await request(method, undefined, {}, `Bearer ${token}`, "/diagnostics/not-hex")).status).toBe(403);
    }
    expect(diagnosticsToken(`Bearer ${token}`)).toBe(token);
    expect((await request("PUT", { events: [event()] })).status).toBe(200);
    expect((await request("GET")).status).toBe(200);
  });

  it("does not treat an allowed browser origin as authentication", async () => {
    const result = await call(`/diagnostics/${id}`, {
      headers: { Origin: APP_ORIGIN },
    }, fakeEnv({ SYNC_DB: env.SYNC_DB }));
    expect(result.status).toBe(403);
    const preflight = await call(`/diagnostics/${id}`, {
      method: "OPTIONS",
      headers: { Origin: APP_ORIGIN, "Access-Control-Request-Method": "PUT" },
    }, fakeEnv({ SYNC_DB: env.SYNC_DB }));
    expect(preflight.status).toBe(204);
    expect(preflight.headers.get("Access-Control-Allow-Headers")).toContain("Authorization");
    expect((await request("DELETE")).status).toBe(404);
  });
});

describe("strict technical-only payloads", () => {
  it("accepts mood technical timing/status without AI semantic data", async () => {
    const item: DiagnosticEvent = {
      ...event(), provider: "cue", operation: "mood", status: "failed", errorCode: "http_5xx",
    };
    expect(await (await request("PUT", { events: [item] })).json()).toEqual({ accepted: 1 });
    expect(await (await request("GET")).json()).toEqual({ events: [item] });
  });

  it.each(["phrase", "text", "requestBody", "responseBody", "url", "providerKey", "rawError"])(
    "rejects mood %s semantic/private additions", async (field) => {
      const item = { ...event(), provider: "cue", operation: "mood" };
      const result = await request("PUT", {
        events: [{ ...item, [field]: "deliberately-synthetic-private-value" }],
      });
      expect(result.status).toBe(400);
      expect(await result.json()).toEqual({ error: "invalid_request" });
      expect((await request("GET")).status).toBe(404);
    },
  );

  it.each(["groq", "gemini"])("does not extend provider enum with %s", async (provider) => {
    const result = await request("PUT", {
      events: [{ ...event(), operation: "mood", provider }],
    });
    expect(result.status).toBe(400);
    expect(await result.json()).toEqual({ error: "invalid_request" });
  });

  it.each(["title", "query", "url", "message", "token", "timestamp", "file", "history", "userId", "email", "synthetic-private-field"])(
    "rejects %s at both event and envelope levels without echo", async (field) => {
      for (const body of [
        { events: [event()], [field]: "synthetic-private-value" },
        { events: [{ ...event(), [field]: "synthetic-private-value" }] },
      ]) {
        const result = await request("PUT", body);
        expect(result.status).toBe(400);
        expect(await result.json()).toEqual({ error: "invalid_request" });
      }
      expect((await request("GET")).status).toBe(404);
    },
  );

  it.each([
    ["requestId", "synthetic-title"], ["requestId", "00000000-0000-1000-8000-000000000000"],
    ["appVersion", "https://example.invalid"], ["appVersion", "0.1.0+synthetic"],
    ["appVersion", "1".repeat(33)], ["provider", "synthetic-name"], ["operation", "synthetic-query"],
    ["durationMs", -1], ["durationMs", 120001], ["durationMs", 1.5], ["durationMs", "100"],
    ["status", "raw-error"], ["errorCode", "raw-error"], ["errorCode", { message: "synthetic" }],
  ])("rejects injected/invalid %s", async (field, value) => {
    expect((await request("PUT", { events: [{ ...event(), [field]: value }] })).status).toBe(400);
  });

  it("requires every field and a batch of 1..20 events; rejects query parameters", async () => {
    for (const field of Object.keys(event())) {
      const incomplete = { ...event() } as Record<string, unknown>;
      delete incomplete[field];
      expect((await request("PUT", { events: [incomplete] })).status).toBe(400);
    }
    for (const body of [{}, { events: [] }, { events: Array.from({ length: 21 }, event) }, { events: null }]) {
      expect((await request("PUT", body)).status).toBe(400);
    }
    expect((await request("PUT", { events: [event()] }, {}, `Bearer ${token}`, `/diagnostics/${id}?query=synthetic`)).status).toBe(400);
    expect((await request("GET", undefined, {}, `Bearer ${token}`, `/diagnostics/${id}?token=synthetic`)).status).toBe(400);
    const batch = Array.from({ length: 20 }, event);
    expect((await request("PUT", { events: batch })).status).toBe(200);
    expect(await (await request("GET")).json()).toEqual({ events: batch });
  });

  it("caps known-length and streamed request bodies at 6 KiB", async () => {
    const payload = JSON.stringify({ events: [event()], pad: "x".repeat(MAX_DIAGNOSTICS_BYTES) });
    expect((await request("PUT", JSON.parse(payload))).status).toBe(413);
    const result = await call(`/diagnostics/${id}`, {
      method: "PUT",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: new ReadableStream({
        start(controller) {
          controller.enqueue(new TextEncoder().encode(payload));
          controller.close();
        },
      }),
      // @ts-expect-error Node/undici streamed request option.
      duplex: "half",
    }, fakeEnv({ SYNC_DB: env.SYNC_DB }));
    expect(result.status).toBe(413);
    const misdeclared = await call(`/diagnostics/${id}`, {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${token}`, "Content-Type": "application/json", "Content-Length": "1",
      },
      body: payload,
    }, fakeEnv({ SYNC_DB: env.SYNC_DB }));
    expect(misdeclared.status).toBe(413);
  });

  it("rejects invalid JSON and non-JSON content types", async () => {
    for (const [type, body] of [
      ["application/json", "{"],
      ["text/plain", JSON.stringify({ events: [event()] })],
    ]) {
      const result = await call(`/diagnostics/${id}`, {
        method: "PUT",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": type! },
        body,
      }, fakeEnv({ SYNC_DB: env.SYNC_DB }));
      expect(result.status).toBe(400);
    }
  });

  it("persists only allowlisted events, server time and capability digest; no raw tokens or logs", async () => {
    const lines: string[] = [];
    vi.spyOn(console, "log").mockImplementation((line: unknown) => lines.push(String(line)));
    vi.spyOn(console, "error").mockImplementation((line: unknown) => lines.push(String(line)));
    const fetch = vi.spyOn(globalThis, "fetch");
    const item = event();
    expect(await (await request("PUT", { events: [item] })).json()).toEqual({ accepted: 1 });
    const response = await request("GET");
    expect(await response.json()).toEqual({ events: [item] });
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    const row = await env.SYNC_DB.prepare("SELECT * FROM diagnostic_sessions WHERE id = ?").bind(id)
      .first<{ id: string; events: string; expires_at: number }>();
    expect(row!.id).toBe(id);
    expect(row!.events).not.toContain(token);
    expect(JSON.parse(row!.events)).toEqual([{ ...item, receivedAt: now }]);
    expect(row!.expires_at).toBe(now + DIAGNOSTICS_MAX_AGE_MS);
    await request("GET", undefined, {}, "Bearer synthetic-invalid");
    await request("PUT", { events: [{ ...item, "synthetic-private-key": "synthetic-private-value" }] });
    await request("DELETE");
    expect(lines.join("\n")).not.toContain(token);
    expect(lines.join("\n")).not.toContain(id);
    expect(lines.join("\n")).not.toContain(item.requestId);
    expect(lines.join("\n")).not.toContain("synthetic");
    expect(fetch).not.toHaveBeenCalled();
  });
});

describe("bounded storage, retention and atomic writes", () => {
  it("deduplicates batches and retries even inside the five-second limit", async () => {
    const item = event();
    expect(await (await request("PUT", { events: [item, item] })).json()).toEqual({ accepted: 1 });
    const upper = { ...item, requestId: item.requestId.toUpperCase() };
    expect(await (await request("PUT", { events: [upper] })).json()).toEqual({ accepted: 0 });
    const limited = await request("PUT", { events: [event()] });
    expect(limited.status).toBe(429);
    expect(await limited.json()).toEqual({ error: "rate_limited" });
    expect(limited.headers.get("Retry-After")).toBe("5");
    vi.mocked(Date.now).mockReturnValue(now + 5000);
    expect(await (await request("PUT", { events: [item, event()] })).json()).toEqual({ accepted: 1 });
  });

  it("keeps the existing per-IP rate limiter", async () => {
    const limiter = fakeLimiter(1);
    expect((await request("GET", undefined, { RATE_LIMITER: limiter })).status).toBe(404);
    const limited = await request("PUT", { events: [event()] }, { RATE_LIMITER: limiter });
    expect(limited.status).toBe(429);
    expect(limited.headers.get("Retry-After")).toBe("60");
    expect(limiter.keys).toEqual(["unknown", "unknown"]);
    expect((await request("GET", undefined, { RATE_LIMITER: undefined as unknown as RateLimit })).status).toBe(503);
  });

  it("caps sessions at 100 events without partial batch acceptance", async () => {
    const store = new DiagnosticsStore(env.SYNC_DB);
    const batch = Array.from({ length: 20 }, event);
    await store.append(id, batch, now);
    for (let i = 1; i < 5; i++) {
      expect(await store.append(id, Array.from({ length: 20 }, event), now + i * 5000))
        .toEqual({ ok: true, accepted: 20 });
    }
    vi.mocked(Date.now).mockReturnValue(now + 25000);
    const result = await request("PUT", { events: [event()] });
    expect(result.status).toBe(429);
    expect(await result.json()).toEqual({ error: "quota_exceeded" });
    expect(await store.append(id, batch, now + 25000)).toEqual({ ok: true, accepted: 0 });
    expect((await store.get(id, now + 25000))!.length).toBe(100);
  });

  it("concurrent first writes and updates never overwrite events or bypass the session rate", async () => {
    const store = new DiagnosticsStore(env.SYNC_DB);
    for (const time of [now, now + 5000]) {
      const attempts = await Promise.all(Array.from({ length: 10 }, () => store.append(id, [event()], time)));
      expect(attempts.filter((result) => result.ok)).toHaveLength(1);
      expect(attempts.filter((result) => !result.ok && result.reason === "rate_limited")).toHaveLength(9);
    }
    expect((await store.get(id, now + 5000))!.length).toBe(2);
  });

  it("concurrent retries are idempotent", async () => {
    const store = new DiagnosticsStore(env.SYNC_DB);
    const batch = [event()];
    const attempts = await Promise.all(Array.from({ length: 10 }, () => store.append(id, batch, now)));
    expect(attempts.every((result) => result.ok)).toBe(true);
    expect(attempts.reduce((n, result) => n + (result.ok ? result.accepted : 0), 0)).toBe(1);
    expect(await store.get(id, now)).toEqual(batch);
  });

  it("cannot race past the per-session event cap", async () => {
    const store = new DiagnosticsStore(env.SYNC_DB);
    await store.append(id, [event()], now);
    await env.SYNC_DB.prepare("UPDATE diagnostic_sessions SET events = ? WHERE id = ?")
      .bind(JSON.stringify(Array.from({ length: 99 }, () => ({ ...event(), receivedAt: now }))), id).run();
    const attempts = await Promise.all(Array.from({ length: 10 }, (_, i) =>
      store.append(id, Array.from({ length: i % 2 + 1 }, event), now + 5000)));
    expect(attempts.filter((result) => result.ok)).toHaveLength(1);
    expect((await store.get(id, now + 5000))!.length).toBe(100);
  });

  it("CAS also guards the session generation when expiry resets its revision", async () => {
    const store = new DiagnosticsStore(env.SYNC_DB);
    const oldEvent = event();
    const freshEvent = event();
    const addedEvent = event();
    await store.append(id, [oldEvent], now);
    let replaced = false;
    const replacementTime = now + DIAGNOSTICS_MAX_AGE_MS;
    const db = {
      prepare(sql: string) {
        const statement = env.SYNC_DB.prepare(sql);
        if (!sql.startsWith("UPDATE")) return statement;
        return {
          bind(...values: unknown[]) {
            const bound = statement.bind(...values);
            return {
              async run() {
                if (!replaced) {
                  replaced = true;
                  await env.SYNC_DB.prepare("DELETE FROM diagnostic_sessions WHERE id = ?").bind(id).run();
                  await store.append(id, [freshEvent], replacementTime);
                }
                return bound.run();
              },
            };
          },
        };
      },
    } as D1Database;
    expect(await new DiagnosticsStore(db).append(id, [addedEvent], now + 5000))
      .toEqual({ ok: false, reason: "rate_limited" });
    expect(await store.get(id, replacementTime)).toEqual([freshEvent]);
  });

  it("global conditional inserts cannot race beyond 1000 sessions", async () => {
    await env.SYNC_DB.prepare(
      `WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<999)
       INSERT INTO diagnostic_sessions (id, events, revision, last_write_at, expires_at)
       SELECT printf('%064x', x), '[]', 1, ?, ? FROM n`,
    ).bind(now, now + DIAGNOSTICS_MAX_AGE_MS).run();
    const store = new DiagnosticsStore(env.SYNC_DB);
    const ids = await Promise.all(Array.from({ length: 10 }, () => sha256Hex(crypto.randomUUID())));
    const attempts = await Promise.all(ids.map((key) => store.append(key, [event()], now)));
    expect(attempts.filter((result) => result.ok)).toHaveLength(1);
    expect(attempts.filter((result) => !result.ok && result.reason === "quota_exceeded")).toHaveLength(9);
    const count = await env.SYNC_DB.prepare("SELECT COUNT(*) AS n FROM diagnostic_sessions").first<{ n: number }>();
    expect(count!.n).toBe(1000);
    expect((await request("PUT", { events: [event()] })).status).toBe(429);
    const winner = ids[attempts.findIndex((result) => result.ok)]!;
    expect(await store.append(winner, [event()], now + 5000)).toEqual({ ok: true, accepted: 1 });
  });

  it("expires exactly seven days after creation, never extended by writes; a new upload can start over", async () => {
    const store = new DiagnosticsStore(env.SYNC_DB);
    await store.append(id, [event()], now);
    await store.append(id, [event()], now + DIAGNOSTICS_MAX_AGE_MS - 1);
    expect((await store.get(id, now + DIAGNOSTICS_MAX_AGE_MS - 1))!.length).toBe(2);
    vi.mocked(Date.now).mockReturnValue(now + DIAGNOSTICS_MAX_AGE_MS);
    expect((await request("GET")).status).toBe(404);
    expect(await env.SYNC_DB.prepare("SELECT id FROM diagnostic_sessions WHERE id = ?").bind(id).first()).toBeNull();
    const fresh = event();
    expect(await (await request("PUT", { events: [fresh] })).json()).toEqual({ accepted: 1 });
    expect(await (await request("GET")).json()).toEqual({ events: [fresh] });
  });

  it("prunes only bounded expired rows and leaves fresh sessions and sync untouched", async () => {
    await env.SYNC_DB.prepare(SCHEMA).run();
    await env.SYNC_DB.prepare(
      "INSERT INTO sync_blobs (id, token_hash, version, data, updated_at) VALUES ('synthetic-sync', 'h', 1, 'synthetic-ciphertext', 0)",
    ).run();
    await env.SYNC_DB.prepare(
      `WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<60)
       INSERT INTO diagnostic_sessions (id, events, revision, last_write_at, expires_at)
       SELECT printf('%064x', x), '[]', 1, 0, ? FROM n`,
    ).bind(now).run();
    const store = new DiagnosticsStore(env.SYNC_DB);
    expect(await store.append(id, [event()], now)).toEqual({ ok: true, accepted: 1 });
    const old = await env.SYNC_DB.prepare("SELECT COUNT(*) AS n FROM diagnostic_sessions WHERE expires_at <= ?")
      .bind(now).first<{ n: number }>();
    expect(old!.n).toBe(35);
    expect(await store.get(id, now)).toHaveLength(1);
    const remaining = await env.SYNC_DB.prepare("SELECT COUNT(*) AS n FROM diagnostic_sessions WHERE expires_at <= ?")
      .bind(now).first<{ n: number }>();
    expect(remaining!.n).toBe(10);
    expect(await env.SYNC_DB.prepare("SELECT data FROM sync_blobs WHERE id = 'synthetic-sync'").first())
      .toEqual({ data: "synthetic-ciphertext" });
  });
});

describe("storage unavailable is explicit", () => {
  it("returns 503 without the binding, without a migration, or on failed D1 operations", async () => {
    for (const method of ["GET", "PUT"]) {
      expect((await request(method, method === "PUT" ? { events: [event()] } : undefined,
        { SYNC_DB: undefined as unknown as D1Database })).status).toBe(503);
    }
    await env.SYNC_DB.prepare("DROP TABLE diagnostic_sessions").run();
    for (const method of ["GET", "PUT"]) {
      const result = await request(method, method === "PUT" ? { events: [event()] } : undefined);
      expect(result.status).toBe(503);
      expect(await result.json()).toEqual({ error: "unavailable" });
    }
  });

  it("does not report success when an append fails after successful reads/pruning", async () => {
    const broken = {
      prepare(sql: string) {
        if (sql.startsWith("INSERT") || sql.startsWith("UPDATE")) throw new Error("synthetic storage failure");
        return env.SYNC_DB.prepare(sql);
      },
    } as D1Database;
    const result = await request("PUT", { events: [event()] }, { SYNC_DB: broken });
    expect(result.status).toBe(503);
    expect(await result.json()).toEqual({ error: "unavailable" });
    expect((await request("GET")).status).toBe(404);
  });

  it("treats unsuccessful D1 result flags as storage failures, not successful writes", async () => {
    const db = {
      prepare() {
        return {
          bind() { return this; },
          async run() { return { success: false, meta: { changes: 1 } }; },
        };
      },
    } as unknown as D1Database;
    for (const method of ["GET", "PUT"]) {
      const result = await request(method, method === "PUT" ? { events: [event()] } : undefined, { SYNC_DB: db });
      expect(result.status).toBe(503);
      expect(await result.json()).toEqual({ error: "unavailable" });
    }
  });

  it("never leaks unknown/corrupt stored fields through GET", async () => {
    const bad = JSON.stringify([{ ...event(), receivedAt: now, title: "synthetic-private-title" }]);
    await env.SYNC_DB.prepare(
      "INSERT INTO diagnostic_sessions VALUES (?, ?, 1, ?, ?)",
    ).bind(id, bad, now, now + DIAGNOSTICS_MAX_AGE_MS).run();
    const result = await request("GET");
    expect(result.status).toBe(503);
    expect(await result.json()).toEqual({ error: "unavailable" });
    expect(diagnosticsBody.safeParse({ events: [event()] }).success).toBe(true);
  });
});
