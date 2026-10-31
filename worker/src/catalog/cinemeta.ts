import {
  type CatalogItem,
  type CatalogPage,
  type MediaKind,
  intOrNull,
  plainText,
} from "./types";
import { fetchJson } from "./upstream";

/**
 * Cinemeta is Stremio's public movie and series catalog. It needs no key
 * and no account. It is an unofficial use of someone else's service, so
 * every call is cached and failures degrade to an empty list.
 */
const CATALOGS = "https://cinemeta-catalogs.strem.io";
const META = "https://v3-cinemeta.strem.io";

export type CinemetaType = "movie" | "series";

/** One genre per request: Cinemeta does not take several. */
const MOOD_GENRE: Record<string, string> = {
  hype: "Action",
  comfort: "Comedy",
  gripping: "Thriller",
  feels: "Romance",
};

const COUNTRY: Record<string, string> = {
  "united states": "US",
  "united kingdom": "GB",
  canada: "CA",
  australia: "AU",
  ireland: "IE",
  "new zealand": "NZ",
  india: "IN",
  france: "FR",
  germany: "DE",
  spain: "ES",
  italy: "IT",
  "south korea": "KR",
  japan: "JP",
  china: "CN",
  taiwan: "TW",
  "hong kong": "HK",
  thailand: "TH",
  mexico: "MX",
  brazil: "BR",
};

type Row = Record<string, any>;

function yearOf(row: Row): number | null {
  const m = /(\d{4})/.exec(String(row.year ?? row.releaseInfo ?? row.released ?? ""));
  return m ? Number(m[1]) : null;
}

export function normalizeCinemeta(r: Row, type: CinemetaType): CatalogItem {
  const countries = String(r.country ?? "")
    .split(",")
    .map((c) => c.trim().toLowerCase())
    .filter(Boolean);
  const code = countries.map((c) => COUNTRY[c]).find(Boolean) ?? null;
  const rating = Number(r.imdbRating);
  const videos: Row[] = Array.isArray(r.videos) ? r.videos : [];
  const bySeason = new Map<number, number>();
  for (const v of videos) {
    const s = Number(v.season);
    if (s > 0) bySeason.set(s, (bySeason.get(s) ?? 0) + 1);
  }
  const poster = typeof r.poster === "string" ? r.poster : null;
  const status = String(r.status ?? "").toLowerCase();
  return {
    provider: "cinemeta",
    providerId: String(r.imdb_id ?? r.id),
    providerKind: type,
    idMal: null,
    kind: type === "movie" ? "movie" : "series",
    titleEn: r.name ?? null,
    titleRomaji: null,
    titleNative: null,
    year: yearOf(r),
    country: code,
    format: type === "movie" ? "MOVIE" : "TV",
    status:
      type === "movie" || status === "ended"
        ? "finished"
        : status === "continuing"
          ? "airing"
          : "unknown",
    episodes: null,
    chapters: null,
    seasons: [...bySeason.entries()]
      .sort((a, b) => a[0] - b[0])
      .map(([number, episodes]) => ({ number, episodes, year: null })),
    genres: Array.isArray(r.genres) ? r.genres.slice(0, 8) : [],
    tags: [],
    score: rating > 0 ? Math.round(rating * 10) : null,
    // The medium poster is sharp on phones at about 100 KB.
    posterUrl: poster ? poster.replace("/poster/small/", "/poster/medium/") : null,
    backdropUrl: typeof r.background === "string" ? r.background : null,
    synopsis: plainText(r.description),
    adult: false,
    franchiseKey: null,
  };
}

function metasOf(body: unknown): Row[] {
  const metas = (body as { metas?: unknown } | null)?.metas;
  return Array.isArray(metas) ? (metas as Row[]) : [];
}

export async function discoverCinemeta(
  type: CinemetaType,
  mood: string | undefined,
  page: number,
): Promise<CatalogPage> {
  const extras = [
    mood && MOOD_GENRE[mood] ? `genre=${MOOD_GENRE[mood]}` : null,
    page > 1 ? `skip=${(page - 1) * 50}` : null,
  ].filter(Boolean);
  const path = extras.length
    ? `/top/catalog/${type}/top/${extras.join("&")}.json`
    : `/top/catalog/${type}/top.json`;
  const items = metasOf(await fetchJson(`${CATALOGS}${path}`)).filter(
    (m) => m.poster && m.name,
  );
  return {
    items: items.map((m) => normalizeCinemeta(m, type)),
    hasNext: items.length > 0 && page < 50,
  };
}

export async function titleCinemeta(
  id: string,
  type: CinemetaType,
): Promise<CatalogItem | null> {
  const body = (await fetchJson(`${META}/meta/${type}/${id}.json`)) as {
    meta?: Row;
  } | null;
  return body?.meta?.name ? normalizeCinemeta(body.meta, type) : null;
}

export async function searchCinemeta(
  q: string,
  type: CinemetaType,
): Promise<CatalogItem[]> {
  const url = `${META}/catalog/${type}/top/search=${encodeURIComponent(q)}.json`;
  return metasOf(await fetchJson(url))
    .filter((m) => m.name)
    .slice(0, 8)
    .map((m) => normalizeCinemeta(m, type));
}

/** Kinds this source can serve. */
export const CINEMETA_KINDS = new Set<MediaKind>(["movie"]);

export function cinemetaType(kind: MediaKind | undefined): CinemetaType {
  return kind === "movie" ? "movie" : "series";
}
