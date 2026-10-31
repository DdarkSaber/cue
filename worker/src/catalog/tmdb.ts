import {
  type CatalogItem,
  type CatalogPage,
  type MediaKind,
  NotConfiguredError,
  intOrNull,
  plainText,
  yearOf,
} from "./types";
import { fetchJson } from "./upstream";

const API = "https://api.themoviedb.org/3";
const IMG = "https://image.tmdb.org/t/p";

export type TmdbType = "tv" | "movie";
export const TMDB_KINDS = new Set<MediaKind>([
  "kdrama",
  "cdrama",
  "jdrama",
  "series",
  "movie",
]);

// Animation, reality, talk and news never count as dramas or series here.
const TV_EXCLUDE = "16,10764,10767,10763";

const ORIGIN: Partial<Record<MediaKind, string>> = {
  kdrama: "KR",
  cdrama: "CN|TW|HK",
  jdrama: "JP",
  series: "US|GB|CA|AU|IN|IE|NZ",
};

const MOOD_TV: Record<string, string> = {
  hype: "10759",
  comfort: "35|10751",
  gripping: "80|9648",
  feels: "18",
};
const MOOD_MOVIE: Record<string, string> = {
  hype: "28|12",
  comfort: "35|10751",
  gripping: "53|80|9648",
  feels: "10749|18",
};

const TV_GENRES: Record<number, string> = {
  10759: "Action & Adventure",
  16: "Animation",
  35: "Comedy",
  80: "Crime",
  99: "Documentary",
  18: "Drama",
  10751: "Family",
  10762: "Kids",
  9648: "Mystery",
  10765: "Sci-Fi & Fantasy",
  10766: "Soap",
  10768: "War & Politics",
  37: "Western",
};
const MOVIE_GENRES: Record<number, string> = {
  28: "Action",
  12: "Adventure",
  16: "Animation",
  35: "Comedy",
  80: "Crime",
  99: "Documentary",
  18: "Drama",
  10751: "Family",
  14: "Fantasy",
  36: "History",
  27: "Horror",
  10402: "Music",
  9648: "Mystery",
  10749: "Romance",
  878: "Science Fiction",
  53: "Thriller",
  10752: "War",
  37: "Western",
};

export function tmdbRequest(key: string | undefined, path: string, params: Record<string, string | number | undefined>) {
  if (!key) throw new NotConfiguredError("tmdb");
  const url = new URL(`${API}${path}`);
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== "") url.searchParams.set(k, String(v));
  }
  const headers: Record<string, string> = { Accept: "application/json" };
  // v4 read tokens are JWTs; v3 keys are short hex strings.
  if (key.startsWith("eyJ")) headers.Authorization = `Bearer ${key}`;
  else url.searchParams.set("api_key", key);
  return fetchJson(url.toString(), { headers });
}

type Row = Record<string, any>;

function kindFromCountries(countries: string[], type: TmdbType): MediaKind {
  if (type === "movie") return "movie";
  if (countries.includes("KR")) return "kdrama";
  if (countries.some((c) => c === "CN" || c === "TW" || c === "HK")) return "cdrama";
  if (countries.includes("JP")) return "jdrama";
  return "series";
}

function statusOf(raw: string | undefined): CatalogItem["status"] {
  switch (raw) {
    case "Ended":
    case "Canceled":
    case "Released":
      return "finished";
    case "Returning Series":
    case "In Production":
      return "airing";
    default:
      return "unknown";
  }
}

export function normalizeTmdb(r: Row, type: TmdbType): CatalogItem {
  const countries: string[] = r.origin_country ??
    (r.production_countries ?? []).map((c: Row) => c.iso_3166_1);
  const names = type === "tv" ? TV_GENRES : MOVIE_GENRES;
  const genres: string[] = Array.isArray(r.genres)
    ? r.genres.map((g: Row) => g.name)
    : (r.genre_ids ?? []).map((id: number) => names[id]).filter(Boolean);
  const keywords: Row[] = r.keywords?.results ?? r.keywords?.keywords ?? [];
  const title: string | null = (type === "tv" ? r.name : r.title) ?? null;
  const original: string | null =
    (type === "tv" ? r.original_name : r.original_title) ?? null;
  const seasons: Row[] = Array.isArray(r.seasons) ? r.seasons : [];
  const vote = typeof r.vote_average === "number" && r.vote_count > 0
    ? Math.round(r.vote_average * 10)
    : null;
  return {
    provider: "tmdb",
    providerId: String(r.id),
    providerKind: type,
    idMal: null,
    kind: kindFromCountries(countries, type),
    titleEn: title,
    titleRomaji: null,
    titleNative: original && original !== title ? original : null,
    year: yearOf(type === "tv" ? r.first_air_date : r.release_date),
    country: countries[0] ?? null,
    format: type === "tv" ? "TV" : "MOVIE",
    status: statusOf(r.status),
    episodes: intOrNull(r.number_of_episodes),
    chapters: null,
    seasons: seasons
      .filter((s) => s.season_number > 0)
      .map((s) => ({
        number: s.season_number,
        episodes: intOrNull(s.episode_count),
        year: yearOf(s.air_date),
      })),
    genres,
    tags: keywords.slice(0, 12).map((k) => String(k.name).toLowerCase()),
    score: vote,
    posterUrl: r.poster_path ? `${IMG}/w500${r.poster_path}` : null,
    backdropUrl: r.backdrop_path ? `${IMG}/w1280${r.backdrop_path}` : null,
    synopsis: plainText(r.overview),
    adult: Boolean(r.adult),
    franchiseKey: r.belongs_to_collection?.id
      ? `tmdb:c${r.belongs_to_collection.id}`
      : null,
  };
}

export async function discoverTmdb(
  key: string | undefined,
  kind: MediaKind,
  mood: string | undefined,
  page: number,
): Promise<CatalogPage> {
  const type: TmdbType = kind === "movie" ? "movie" : "tv";
  const body = (await tmdbRequest(key, `/discover/${type}`, {
    sort_by: "popularity.desc",
    "vote_count.gte": type === "movie" ? 300 : 40,
    include_adult: "false",
    with_origin_country: ORIGIN[kind],
    without_genres: type === "tv" ? TV_EXCLUDE : undefined,
    with_genres: mood ? (type === "tv" ? MOOD_TV : MOOD_MOVIE)[mood] : undefined,
    page,
  })) as Row | null;
  const results: Row[] = body?.results ?? [];
  return {
    items: results
      .filter((r) => !r.adult)
      .map((r) => {
        const item = normalizeTmdb(r, type);
        // Discover lists by origin, so the asked-for kind is authoritative.
        return { ...item, kind };
      }),
    hasNext: (body?.page ?? 0) < (body?.total_pages ?? 0),
  };
}

export async function titleTmdb(
  key: string | undefined,
  id: string,
  type: TmdbType,
): Promise<CatalogItem | null> {
  const r = (await tmdbRequest(key, `/${type}/${id}`, {
    append_to_response: "keywords",
  })) as Row | null;
  return r ? normalizeTmdb(r, type) : null;
}

export async function searchTmdb(
  key: string | undefined,
  q: string,
  kind: MediaKind | undefined,
): Promise<CatalogItem[]> {
  const type = kind === "movie" ? "movie" : kind && TMDB_KINDS.has(kind) ? "tv" : "multi";
  const body = (await tmdbRequest(key, `/search/${type}`, {
    query: q,
    include_adult: "false",
  })) as Row | null;
  const results: Row[] = body?.results ?? [];
  return results
    .filter((r) => type !== "multi" || r.media_type === "tv" || r.media_type === "movie")
    .slice(0, 10)
    .map((r) =>
      normalizeTmdb(r, type === "multi" ? (r.media_type as TmdbType) : type),
    );
}

export interface WatchProviders {
  region: string;
  link: string | null;
  stream: string[];
  free: string[];
  rent: string[];
  buy: string[];
}

export async function providersTmdb(
  key: string | undefined,
  id: string,
  type: TmdbType,
  region: string,
): Promise<WatchProviders> {
  const body = (await tmdbRequest(key, `/${type}/${id}/watch/providers`, {})) as Row | null;
  const r: Row = body?.results?.[region] ?? {};
  const names = (list: Row[] | undefined) =>
    (list ?? []).slice(0, 12).map((p) => String(p.provider_name));
  return {
    region,
    link: typeof r.link === "string" ? r.link : null,
    stream: names(r.flatrate),
    free: names([...(r.free ?? []), ...(r.ads ?? [])]),
    rent: names(r.rent),
    buy: names(r.buy),
  };
}
