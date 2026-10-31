declare global {
  namespace Cloudflare {
    // Bindings from wrangler.toml; merged into the runtime's `env` type.
    interface Env {
      CATALOG_CACHE: KVNamespace;
      RATE_LIMITER: RateLimit;
      ALLOWED_ORIGINS: string;
    }
    interface GlobalProps {
      mainModule: typeof import("./index");
    }
  }
}

export type Env = Cloudflare.Env;

export type AppEnv = { Bindings: Env };
