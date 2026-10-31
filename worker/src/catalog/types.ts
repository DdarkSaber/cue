import type { z } from "zod";

import type { catalogProvider, mediaKind } from "../schemas";

export type MediaKind = z.infer<typeof mediaKind>;
export type CatalogProvider = z.infer<typeof catalogProvider>;

export type TitleStatus = "finished" | "airing" | "ongoing" | "unknown";

/**
 * One title as the app receives it, whatever the provider.
 * Unknown stays unknown: missing counts and years are null, never 0.
 */
export interface CatalogItem {
  provider: CatalogProvider;
  providerId: string;
  /** "tv" or "movie" for TMDB; null elsewhere. */
  providerKind: string | null;
  idMal: number | null;
  kind: MediaKind;
  titleEn: string | null;
  titleRomaji: string | null;
  titleNative: string | null;
  year: number | null;
  country: string | null;
  format: string | null;
  status: TitleStatus;
  episodes: number | null;
  chapters: number | null;
  seasons: { number: number; episodes: number | null; year: number | null }[];
  genres: string[];
  tags: string[];
  /** 0 to 100, or null when the provider has no score. */
  score: number | null;
  posterUrl: string | null;
  backdropUrl: string | null;
  synopsis: string | null;
  adult: boolean;
  /** Franchise hint: the provider id of the earliest related title, if known. */
  franchiseKey: string | null;
}

export interface CatalogPage {
  items: CatalogItem[];
  hasNext: boolean;
}

/** Thrown when a provider fails; mapped to a 502 without upstream details. */
export class UpstreamError extends Error {
  override name = "UpstreamError";
}

/** Thrown when a provider needs a key the Worker does not have. */
export class NotConfiguredError extends Error {
  override name = "NotConfiguredError";
}

/** Strips HTML from provider synopses and caps their length. */
export function plainText(raw: string | null | undefined, max = 1200) {
  if (!raw) return null;
  const text = raw
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<[^>]*>/g, "")
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;|&apos;/g, "'")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
  if (!text) return null;
  return text.length > max ? `${text.slice(0, max - 1).trimEnd()}…` : text;
}

export function intOrNull(v: unknown): number | null {
  return typeof v === "number" && Number.isFinite(v) && v > 0
    ? Math.round(v)
    : null;
}

export function yearOf(date: string | null | undefined): number | null {
  const m = /^(\d{4})/.exec(date ?? "");
  return m ? Number(m[1]) : null;
}
