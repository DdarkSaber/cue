declare global {
  namespace Cloudflare {
    // Bindings from wrangler.toml; merged into the runtime's `env` type.
    interface Env {
      CATALOG_CACHE: KVNamespace;
      /** Encrypted sync blobs only. */
      SYNC_DB: D1Database;
      RATE_LIMITER: RateLimit;
      /** Looser per-IP limit for poster loads on the web app. */
      IMAGE_LIMITER: RateLimit;
      ALLOWED_ORIGINS: string;
      /** Secret. Without it, TMDB-backed kinds answer 503 not_configured. */
      TMDB_API_KEY?: string;
      /** Secrets for sign-in imports. Absent ones keep that source off. */
      MAL_CLIENT_ID?: string;
      MAL_CLIENT_SECRET?: string;
    }
    interface GlobalProps {
      mainModule: typeof import("./index");
    }
  }
}

export type Env = Cloudflare.Env;

export type AppEnv = { Bindings: Env };
