import { env, exports } from "cloudflare:workers";
import { describe, expect, it } from "vitest";
import * as entrypoint from "../src/index";

// Runs inside workerd with the bindings from wrangler.toml.
describe("deployed shape", () => {
  it("exports only the Worker handler from the runtime entrypoint", () => {
    expect(Object.keys(entrypoint)).toEqual(["default"]);
    expect(typeof entrypoint.default.fetch).toBe("function");
    expect(typeof entrypoint.default.scheduled).toBe("function");
  });

  it("has the KV cache and rate-limit bindings", () => {
    expect(env.CATALOG_CACHE).toBeDefined();
    expect(typeof env.RATE_LIMITER.limit).toBe("function");
  });

  it("serves the fixed routes through the real entry point", async () => {
    const routed = await exports.default.fetch("https://api.test/ai/mood", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{}",
    });
    expect(routed.status).toBe(400);
    const missing = await exports.default.fetch("https://api.test/anything");
    expect(missing.status).toBe(404);
  });
});
