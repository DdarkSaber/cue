import {
  type CatalogItem,
  type MediaKind,
  intOrNull,
  plainText,
  yearOf,
} from "./types";
import { fetchJson } from "./upstream";

const API = "https://api.tvmaze.com";

type Row = Record<string, any>;

function kindOf(country: string | null, language: string | null, genres: string[]): MediaKind {
  if (genres.includes("Anime")) return "anime";
  if (country === "KR" || language === "Korean") return "kdrama";
  if (country === "CN" || country === "TW" || country === "HK" || language === "Chinese") {
    return "cdrama";
  }
  if (country === "JP" || language === "Japanese") return "jdrama";
  return "series";
}

export function normalizeTvmaze(s: Row): CatalogItem {
  const country: string | null =
    s.network?.country?.code ?? s.webChannel?.country?.code ?? null;
  const seasons: Row[] = s._embedded?.seasons ?? [];
  const rating = s.rating?.average;
  return {
    provider: "tvmaze",
    providerId: String(s.id),
    providerKind: null,
    idMal: null,
    kind: kindOf(country, s.language ?? null, s.genres ?? []),
    titleEn: s.name ?? null,
    titleRomaji: null,
    titleNative: null,
    year: yearOf(s.premiered),
    country,
    format: "TV",
    status: s.status === "Ended" ? "finished" : s.status === "Running" ? "airing" : "unknown",
    episodes: null,
    chapters: null,
    seasons: seasons
      .filter((x) => x.number > 0)
      .map((x) => ({
        number: x.number,
        episodes: intOrNull(x.episodeOrder),
        year: yearOf(x.premiereDate),
      })),
    genres: Array.isArray(s.genres) ? s.genres : [],
    tags: [],
    score: typeof rating === "number" ? Math.round(rating * 10) : null,
    posterUrl: s.image?.original ?? s.image?.medium ?? null,
    backdropUrl: null,
    synopsis: plainText(s.summary),
    adult: false,
    franchiseKey: null,
  };
}

export async function titleTvmaze(id: string): Promise<CatalogItem | null> {
  const s = (await fetchJson(`${API}/shows/${id}?embed=seasons`)) as Row | null;
  return s ? normalizeTvmaze(s) : null;
}

export async function searchTvmaze(q: string): Promise<CatalogItem[]> {
  const url = new URL(`${API}/search/shows`);
  url.searchParams.set("q", q);
  const rows = ((await fetchJson(url.toString())) as Row[] | null) ?? [];
  return rows.slice(0, 10).map((r) => normalizeTvmaze(r.show ?? {}));
}
