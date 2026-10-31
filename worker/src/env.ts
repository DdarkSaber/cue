declare global {
  namespace Cloudflare {
    // Bindings from wrangler.toml; merged into the runtime's `env` type.
    interface Env {
      CATALOG_CACHE: KVNamespace;
      RATE_LIMITER: RateLimit;
      /** Looser per-IP limit for poster loads on the web app. */
      IMAGE_LIMITER: RateLimit;
      ALLOWED_ORIGINS: string;
      /** Secret. Without it, TMDB-backed kinds answer 503 not_configured. */
      TMDB_API_KEY?: string;
    }
    interface GlobalProps {
      mainModule: typeof import("./index");
    }
  }
}

export type Env = Cloudflare.Env;

export type AppEnv = { Bindings: Env };
