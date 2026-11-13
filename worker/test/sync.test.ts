import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, it, vi } from "vitest";

import type { Env } from "../src/env";

import { MAX_SYNC_BYTES, MAX_SYNC_ROWS, MAX_SYNC_TOTAL_BYTES, SCHEMA, SyncStore } from "../src/sync/store";
import { APP_ORIGIN, call, fakeEnv, fakeLimiter } from "./helpers";

// Uses the local D1 that the Workers test pool provides from wrangler.toml.
const id = "0123456789abcdef0123456789abcdef";
const token = "t".repeat(43);
const other = "o".repeat(43);
const blob = "QUJDREVGR0hJSktMTU5PUA==";

function syncEnv(overrides: Partial<Env> = {}) {
  return fakeEnv({ SYNC_DB: env.SYNC_DB, ...overrides });
}

function req(method: string, body?: unknown, auth = token, path = `/sync/${id}`, e = syncEnv()) {
  return call(
    path,
    {
      method,
      headers: {
        Authorization: `Bearer ${auth}`,
        ...(body ? { "Content-Type": "application/json" } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    },
    e,
  );
}

beforeEach(async () => {
  await env.SYNC_DB.prepare(SCHEMA).run();
  await env.SYNC_DB.prepare("DELETE FROM sync_blobs").run();
});

describe("encrypted sync", () => {
  it("creates, reads, and bumps the version", async () => {
    expect((await req("GET")).status).toBe(404);
    const created = await req("PUT", { version: 0, data: blob });
    expect(await created.json()).toEqual({ version: 1 });
    const got = (await (await req("GET")).json()) as { version: number; data: string };
    expect(got).toMatchObject({ version: 1, data: blob });
    expect(await (await req("PUT", { version: 1, data: blob + "AA" })).json()).toEqual({ version: 2 });
  });

  it("stores only a hash of the token", async () => {
    await req("PUT", { version: 0, data: blob });
    const row = await env.SYNC_DB.prepare("SELECT token_hash FROM sync_blobs").first<{ token_hash: string }>();
    expect(row!.token_hash).toMatch(/^[a-f0-9]{64}$/);
    expect(row!.token_hash).not.toContain(token);
  });

  it("a stale version gets 409 with the current one", async () => {
    await req("PUT", { version: 0, data: blob });
    await req("PUT", { version: 1, data: blob });
    const stale = await req("PUT", { version: 1, data: blob });
    expect(stale.status).toBe(409);
    expect(await stale.json()).toEqual({ error: "conflict", version: 2 });
    // Creating over an existing blob is also a conflict, never an overwrite.
    expect((await req("PUT", { version: 0, data: blob })).status).toBe(409);
  });

  it("another token can neither read, write nor delete, and sees 404 like a missing id", async () => {
    await req("PUT", { version: 0, data: blob });
    for (const res of [
      await req("GET", undefined, other),
      await req("PUT", { version: 1, data: blob }, other),
      await req("PUT", { version: 0, data: blob }, other),
      await req("DELETE", undefined, other),
    ]) {
      expect(res.status).toBe(404);
      expect(await res.json()).toEqual({ error: "not_found" });
    }
    expect((await req("GET")).status).toBe(200);
  });

  it("delete removes the blob", async () => {
    await req("PUT", { version: 0, data: blob });
    expect(await (await req("DELETE")).json()).toEqual({ deleted: true });
    expect((await req("GET")).status).toBe(404);
  });

  it("validates ids, tokens and payloads", async () => {
    expect((await req("GET", undefined, token, "/sync/NOT-HEX")).status).toBe(400);
    expect((await req("GET", undefined, "short")).status).toBe(400);
    expect((await req("PUT", { version: 0, data: "<script>" })).status).toBe(400);
  });

  it("accepts large encrypted bodies on /sync only", async () => {
    const big = "A".repeat(100_000);
    expect((await req("PUT", { version: 0, data: big })).status).toBe(200);
    const res = await call(
      "/catalog/match",
      { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ items: [], pad: big }) },
      syncEnv(),
    );
    expect(res.status).toBe(413);
  });

  it("never logs the token", async () => {
    const lines: string[] = [];
    vi.spyOn(console, "log").mockImplementation((m: unknown) => lines.push(String(m)));
    await req("PUT", { version: 0, data: blob });
    expect(lines.join("\n")).not.toContain(token);
    expect(lines.join("\n")).not.toContain(id);
    vi.restoreAllMocks();
  });

  it("CORS allows PUT and DELETE for the app origin", async () => {
    const res = await call(`/sync/${id}`, {
      method: "OPTIONS",
      headers: { Origin: APP_ORIGIN, "Access-Control-Request-Method": "PUT" },
    }, syncEnv());
    expect(res.headers.get("Access-Control-Allow-Methods")).toContain("PUT");
  });

  it("prunes copies untouched for too long and keeps fresh ones", async () => {
    const day = 24 * 60 * 60 * 1000;
    const now = Date.UTC(2026, 10, 1);
    const insert = env.SYNC_DB.prepare(
      "INSERT INTO sync_blobs (id, token_hash, version, data, updated_at) VALUES (?, 'h', 1, 'x', ?)",
    );
    await insert.bind("old", now - 200 * day).run();
    await insert.bind("fresh", now - 10 * day).run();
    expect(await new SyncStore(env.SYNC_DB).prune(now, 180 * day)).toBe(1);
    const left = await env.SYNC_DB.prepare("SELECT id FROM sync_blobs").all<{ id: string }>();
    expect(left.results.map((r) => r.id)).toEqual(["fresh"]);
  });

  /** Fills the table with synthetic rows straight through SQL (fast, no API). */
  async function fill(rows: number, bytesEach = 1) {
    const stmts = Array.from({ length: rows }, (_, i) =>
      env.SYNC_DB.prepare(
        "INSERT INTO sync_blobs (id, token_hash, version, data, updated_at) VALUES (?, 'h', 1, ?, 0)",
      ).bind(`fill${i}`, "A".repeat(bytesEach)),
    );
    for (let s = 0; s < stmts.length; s += 500) await env.SYNC_DB.batch(stmts.slice(s, s + 500));
  }

  it("refuses creates past the row cap with 429 quota_exceeded, but still allows updates", async () => {
    await req("PUT", { version: 0, data: blob });
    await fill(MAX_SYNC_ROWS - 1);
    const other = "fedcba9876543210fedcba9876543210";
    const refused = await req("PUT", { version: 0, data: blob }, token, `/sync/${other}`);
    expect(refused.status).toBe(429);
    expect(refused.headers.get("Retry-After")).toBe("86400");
    expect(await refused.json()).toEqual({ error: "quota_exceeded" });
    expect((await req("GET", undefined, token, `/sync/${other}`)).status).toBe(404);
    // The existing copy keeps syncing.
    expect(await (await req("PUT", { version: 1, data: blob + "AA" })).json()).toEqual({ version: 2 });
  });

  it("refuses any write that would push total bytes past the byte cap", async () => {
    const store = new SyncStore(env.SYNC_DB, { rows: MAX_SYNC_ROWS, bytes: 100 });
    await fill(1, 50);
    expect(await store.put(id, token, 0, "A".repeat(40), 1)).toEqual({ ok: true, version: 1 });
    // 50 + 40 stored; growing to 60 would make 110.
    expect(await store.put(id, token, 1, "A".repeat(60), 2)).toEqual({ ok: false, reason: "quota_exceeded" });
    // The row's old size is replaced, not counted twice: 50 + 50 fits.
    expect(await store.put(id, token, 1, "A".repeat(50), 3)).toEqual({ ok: true, version: 2 });
    expect(await store.put("fedcba9876543210fedcba9876543210", token, 0, "A", 4)).toEqual({ ok: false, reason: "quota_exceeded" });
    // A wrong token or stale version is still reported as such, not as quota.
    expect(await store.put(id, other, 2, "A", 5)).toEqual({ ok: false, reason: "not_found" });
    expect(await store.put(id, token, 1, "A", 5)).toEqual({ ok: false, reason: "conflict", version: 2 });
    expect(MAX_SYNC_TOTAL_BYTES).toBe(400_000_000);
  });

  it("a stale version under the caps is still a 409 conflict, not a quota error", async () => {
    await req("PUT", { version: 0, data: blob });
    const stale = await req("PUT", { version: 5, data: blob });
    expect(stale.status).toBe(409);
    expect(await stale.json()).toEqual({ error: "conflict", version: 1 });
  });

  it("uses the stricter create limiter for version 0 only", async () => {
    const create = fakeLimiter(1);
    const general = fakeLimiter();
    const e = syncEnv({ SYNC_CREATE_LIMITER: create, RATE_LIMITER: general });
    expect((await req("PUT", { version: 0, data: blob }, token, `/sync/${id}`, e)).status).toBe(200);
    expect(create.keys).toHaveLength(1);
    // Updates and reads do not touch the create limiter.
    expect((await req("PUT", { version: 1, data: blob }, token, `/sync/${id}`, e)).status).toBe(200);
    expect((await req("GET", undefined, token, `/sync/${id}`, e)).status).toBe(200);
    expect(create.keys).toHaveLength(1);
    const second = await req("PUT", { version: 0, data: blob }, token, "/sync/fedcba9876543210fedcba9876543210", e);
    expect(second.status).toBe(429);
    expect(second.headers.get("Retry-After")).toBe("60");
    expect(await second.json()).toEqual({ error: "rate_limited" });
  });

  it("falls back to the general limiter for creates when the create binding is absent", async () => {
    const general = fakeLimiter();
    await req("PUT", { version: 0, data: blob }, token, `/sync/${id}`, syncEnv({ RATE_LIMITER: general }));
    // Once in the middleware, once more for the create.
    expect(general.keys).toHaveLength(2);
  });

  it("answers 413, not a D1 error, for bodies near D1's 2 MB value limit", async () => {
    expect(MAX_SYNC_BYTES).toBeLessThan(2_000_000);
    const tooBig = await req("PUT", { version: 0, data: "A".repeat(1_999_000) });
    expect(tooBig.status).toBe(413);
    expect(await tooBig.json()).toEqual({ error: "payload_too_large" });
    const fits = await req("PUT", { version: 0, data: "A".repeat(MAX_SYNC_BYTES - 64) });
    expect(fits.status).toBe(200);
  });
});
