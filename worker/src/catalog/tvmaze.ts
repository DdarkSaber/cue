import {
  type CatalogItem,
  type CatalogPage,
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

const ASIAN = new Set(["KR", "CN", "TW", "HK", "JP"]);
const MOOD_GENRES: Record<string, string[]> = {
  hype: ["action", "adventure", "sports"],
  comfort: ["comedy", "family"],
  gripping: ["crime", "thriller", "mystery", "legal"],
  feels: ["romance", "drama"],
};

/** TVmaze pages are 250 shows, oldest first; Cue reads them newest first. */
const PAGES_PER_DISCOVER = 4;
const LAST_PAGE_HINT = 381;

function countryOf(s: Row): string | null {
  return s.network?.country?.code ?? s.webChannel?.country?.code ?? null;
}

/** Whether a show belongs in a Cue kind (scripted, with art, popular enough). */
export function fitsKind(s: Row, kind: MediaKind): boolean {
  if (s.type !== "Scripted" || !s.image) return false;
  const genres: string[] = s.genres ?? [];
  if (genres.includes("Anime")) return false;
  const c = countryOf(s);
  const lang = s.language ?? null;
  const weight = Number(s.weight ?? 0);
  switch (kind) {
    case "kdrama":
      return (c === "KR" || (c === null && lang === "Korean")) && weight >= 40;
    case "cdrama":
      return (
        (c === "CN" || c === "TW" || c === "HK" || (c === null && lang === "Chinese")) &&
        weight >= 40
      );
    case "jdrama":
      return (c === "JP" || (c === null && lang === "Japanese")) && weight >= 40;
    case "series":
      return (
        !ASIAN.has(c ?? "") &&
        lang === "English" &&
        weight >= 60
      );
    default:
      return false;
  }
}

/** The newest page number, found by probing from a recent hint. */
export async function tvmazeLastPage(): Promise<number> {
  const exists = async (p: number) => (await fetchJson(`${API}/shows?page=${p}`)) !== null;
  let p = LAST_PAGE_HINT;
  if (await exists(p)) {
    while (await exists(p + 1)) p++;
    return p;
  }
  while (p > 0 && !(await exists(p - 1))) p--;
  return Math.max(0, p - 1);
}

/**
 * One discover page for a drama or series kind: a few TVmaze pages from the
 * newest end, filtered on country, language, art and popularity.
 */
export async function discoverTvmaze(
  kind: MediaKind,
  mood: string | undefined,
  page: number,
  lastPage: number,
): Promise<CatalogPage> {
  const first = lastPage - (page - 1) * PAGES_PER_DISCOVER;
  const wanted = Array.from({ length: PAGES_PER_DISCOVER }, (_, i) => first - i).filter((p) => p >= 0);
  const pages = await Promise.all(
    wanted.map((p) => fetchJson(`${API}/shows?page=${p}`) as Promise<Row[] | null>),
  );
  const genres = mood ? MOOD_GENRES[mood] : undefined;
  const items = pages
    .flatMap((rows) => rows ?? [])
    .filter((s) => fitsKind(s, kind))
    .filter(
      (s) =>
        !genres ||
        (s.genres ?? []).some((g: string) => genres.includes(String(g).toLowerCase())),
    )
    .sort((a, b) => Number(b.weight ?? 0) - Number(a.weight ?? 0))
    .map((s) => ({ ...normalizeTvmaze(s), kind }));
  return { items, hasNext: first - PAGES_PER_DISCOVER >= 0 && page < 500 };
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
