declare global {
  namespace Cloudflare {
    // Bindings from wrangler.toml; merged into the runtime's `env` type.
    interface Env {
      CATALOG_CACHE: KVNamespace;
      /** Encrypted sync and separate opt-in technical diagnostics tables. */
      SYNC_DB: D1Database;
      RATE_LIMITER: RateLimit;
      /** Looser per-IP limit for poster loads on the web app. */
      IMAGE_LIMITER: RateLimit;
      /** Stricter per-IP limit for /ai/mood, which spends free AI quota. */
      AI_LIMITER?: RateLimit;
      /** Stricter per-IP limit for /catalog/match and /catalog/aliases (many upstream calls per request). */
      HEAVY_LIMITER?: RateLimit;
      /** Per-IP limit for /catalog/mal-search and /catalog/names (up to 8 cached lookups each). */
      LOOKUP_LIMITER?: RateLimit;
      ALLOWED_ORIGINS: string;
      /** Secret. Without it, TMDB-backed kinds answer 503 not_configured. */
      TMDB_API_KEY?: string;
      /** Secrets for sign-in imports. Absent ones keep that source off. */
      MAL_CLIENT_ID?: string;
      MAL_CLIENT_SECRET?: string;
      GROQ_API_KEY?: string;
      GEMINI_API_KEY?: string;
      GROQ_MODEL?: string;
      GEMINI_MODEL?: string;
    }
    interface GlobalProps {
      mainModule: typeof import("./index");
    }
  }
}

export type Env = Cloudflare.Env;

export type AppEnv = { Bindings: Env };
