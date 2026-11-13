import { env } from "cloudflare:workers";
import { beforeEach } from "vitest";

import aiUsage from "../migrations/0003_ai_usage.sql?raw";
import { resetClientIpWarning } from "../src/middleware";
import { resetBreakers } from "../src/resilience";

// Circuit state is per isolate; tests must not leak an open circuit into each other.
beforeEach(() => resetBreakers());

// AI daily counters live in D1; every test starts from zero.
beforeEach(async () => {
  resetClientIpWarning();
  await env.SYNC_DB.prepare(aiUsage.replace(/--[^\n]*/g, "")).run();
  await env.SYNC_DB.prepare("DELETE FROM ai_usage").run();
});
