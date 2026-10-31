import { z } from "zod";

/** Media kinds the catalog can discover (everything but unknown). */
export const mediaKind = z.enum([
  "anime",
  "manga",
  "manhwa",
  "manhua",
  "kdrama",
  "cdrama",
  "jdrama",
  "series",
  "movie",
]);

/** TMDB splits ids by type; other providers ignore it. */
export const tmdbType = z.enum(["tv", "movie", "series"]).default("tv");

export const mood = z.enum(["hype", "comfort", "gripping", "feels"]);
export const catalogProvider = z.enum(["anilist", "tmdb", "tvmaze", "cinemeta"]);
export const oauthProvider = z.enum(["mal", "anilist", "trakt"]);
const numericId = z.string().regex(/^\d{1,12}$/);

/** Only official catalog image hosts. */
export const IMAGE_HOSTS = new Set([
  "s4.anilist.co",
  "image.tmdb.org",
  "static.tvmaze.com",
  "images.metahub.space",
]);

export function isAllowedImageUrl(raw: string): boolean {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return false;
  }
  return (
    url.protocol === "https:" &&
    url.port === "" &&
    url.username === "" &&
    url.password === "" &&
    IMAGE_HOSTS.has(url.hostname)
  );
}

export const discoverQuery = z.object({
  kind: mediaKind,
  mood: mood.optional(),
  page: z.coerce.number().int().min(1).max(50).default(1),
});

export const titleParams = z.object({
  provider: catalogProvider,
  // Numeric ids, or IMDb ids (tt1234567) for Cinemeta.
  id: z.string().regex(/^(tt)?\d{1,12}$/),
});
export const titleQuery = z.object({ type: tmdbType });

export const searchQuery = z.object({
  q: z.string().trim().min(1).max(200),
  kind: mediaKind.optional(),
});

export const providersParams = z.object({ tmdbId: numericId });
export const providersQuery = z.object({
  region: z
    .string()
    .regex(/^[A-Z]{2}$/)
    .default("IN"),
  type: tmdbType,
});

export const imageQuery = z.object({
  u: z.string().max(512).refine(isAllowedImageUrl),
});

export const oauthParams = z.object({ provider: oauthProvider });
export const oauthBody = z.object({
  code: z.string().min(1).max(2048),
  codeVerifier: z.string().min(43).max(128).optional(),
  redirectUri: z.string().url().max(512),
});

export const moodBody = z.object({ text: z.string().trim().min(1).max(200) });

/**
 * Batch matching for imports: at most 15 titles (AniList caps query
 * complexity at 500; 15 aliases x 3 results stays under it), plus MAL ids.
 */
export const matchBody = z.object({
  items: z
    .array(
      z.object({
        q: z.string().trim().min(1).max(160),
        kind: mediaKind.optional(),
      }),
    )
    .max(15)
    .default([]),
  malAnime: z.array(z.number().int().positive().max(1e9)).max(50).default([]),
  malManga: z.array(z.number().int().positive().max(1e9)).max(50).default([]),
});

/** Alias lookups for imports: at most 8 names per request. */
export const aliasBody = z.object({
  items: z
    .array(z.object({ q: z.string().trim().min(1).max(160) }))
    .min(1)
    .max(8),
});

/** Usernames on MAL and AniList: letters, digits, underscore, hyphen. */
export const userParams = z.object({
  name: z.string().regex(/^[A-Za-z0-9_-]{2,32}$/),
});
export const listProvider = z.object({ provider: oauthProvider });

/** Bearer tokens are opaque; bounded and printable only. */
export function bearer(header: string | undefined): string | null {
  const m = /^Bearer ([!-~]{10,4096})$/.exec(header ?? "");
  return m ? m[1]! : null;
}

/** Sync ids are 128-bit hex digests derived on the device. */
export const syncParams = z.object({ id: z.string().regex(/^[a-f0-9]{32}$/) });
export const syncBody = z.object({
  version: z.number().int().min(0).max(1e9),
  // Base64 ciphertext; the 2 MB body cap bounds it first.
  data: z.string().min(16).max(2_900_000).regex(/^[A-Za-z0-9+/=_-]+$/),
});
