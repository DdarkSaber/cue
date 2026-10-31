import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { SCHEMA } from "../src/sync/store";
import { APP_ORIGIN, call, fakeEnv } from "./helpers";

// Uses the local D1 that the Workers test pool provides from wrangler.toml.
const id = "0123456789abcdef0123456789abcdef";
const token = "t".repeat(43);
const other = "o".repeat(43);
const blob = "QUJDREVGR0hJSktMTU5PUA==";

function syncEnv() {
  return fakeEnv({ SYNC_DB: env.SYNC_DB });
}

function req(method: string, body?: unknown, auth = token, path = `/sync/${id}`) {
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
    syncEnv(),
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

  it("another token can neither read, write nor delete", async () => {
    await req("PUT", { version: 0, data: blob });
    expect((await req("GET", undefined, other)).status).toBe(403);
    expect((await req("PUT", { version: 1, data: blob }, other)).status).toBe(403);
    expect((await req("DELETE", undefined, other)).status).toBe(403);
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
});
