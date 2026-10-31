import { env, exports } from "cloudflare:workers";
import { describe, expect, it } from "vitest";

// Runs inside workerd with the bindings from wrangler.toml.
describe("deployed shape", () => {
  it("has the KV cache and rate-limit bindings", () => {
    expect(env.CATALOG_CACHE).toBeDefined();
    expect(typeof env.RATE_LIMITER.limit).toBe("function");
  });

  it("serves the fixed routes through the real entry point", async () => {
    const ok = await exports.default.fetch(
      "https://api.test/catalog/discover?kind=anime",
    );
    expect(ok.status).toBe(501);
    const missing = await exports.default.fetch("https://api.test/anything");
    expect(missing.status).toBe(404);
  });
});
