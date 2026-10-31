import { z } from "zod";

/** Media kinds the catalog can discover (CUE-HANDOFF 5.1, minus movie/unknown). */
export const mediaKind = z.enum([
  "anime",
  "manga",
  "manhwa",
  "manhua",
  "kdrama",
  "cdrama",
  "jdrama",
  "series",
]);

export const mood = z.enum(["hype", "comfort", "gripping", "feels"]);
export const catalogProvider = z.enum(["anilist", "tmdb", "tvmaze"]);
export const oauthProvider = z.enum(["mal", "anilist", "trakt"]);
const numericId = z.string().regex(/^\d{1,12}$/);

/** Only official catalog image hosts (CUE-HANDOFF 7.4). */
export const IMAGE_HOSTS = new Set([
  "s4.anilist.co",
  "image.tmdb.org",
  "static.tvmaze.com",
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
  id: numericId,
});

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
