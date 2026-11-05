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

/**
 * MyAnimeList as a backup catalog for anime and comics, used only when the
 * app reports that AniList failed. Needs only Cue's public client id.
 */
const API = "https://api.myanimelist.net/v2";
const PER_PAGE = 50;

type Row = Record<string, any>;

const FIELDS =
  "id,title,alternative_titles,main_picture,start_date,synopsis,mean,genres,media_type,status,num_episodes,num_chapters,nsfw,rating";

/** Which MAL ranking lists each kind: popularity for anime, the comic format's own list otherwise. */
function ranking(kind: MediaKind): { type: "anime" | "manga"; list: string } | null {
  switch (kind) {
    case "anime":
      return { type: "anime", list: "bypopularity" };
    case "manga":
      return { type: "manga", list: "manga" };
    case "manhwa":
      return { type: "manga", list: "manhwa" };
    case "manhua":
      return { type: "manga", list: "manhua" };
    default:
      return null;
  }
}

function kindOf(type: "anime" | "manga", mediaType: unknown): MediaKind {
  if (type === "anime") return "anime";
  return mediaType === "manhwa" ? "manhwa" : mediaType === "manhua" ? "manhua" : "manga";
}

function statusOf(s: unknown, type: "anime" | "manga"): CatalogItem["status"] {
  switch (s) {
    case "finished_airing":
    case "finished":
      return "finished";
    case "currently_airing":
      return "airing";
    case "currently_publishing":
      return type === "anime" ? "airing" : "ongoing";
    case "on_hiatus":
      return "ongoing";
    default:
      return "unknown";
  }
}

export function normalizeMal(n: Row, type: "anime" | "manga"): CatalogItem {
  const alt = n.alternative_titles ?? {};
  const mediaType = typeof n.media_type === "string" ? n.media_type : null;
  return {
    provider: "mal",
    providerId: String(n.id),
    providerKind: type,
    idMal: intOrNull(n.id),
    kind: kindOf(type, mediaType),
    titleEn: typeof alt.en === "string" && alt.en ? alt.en : null,
    titleRomaji: typeof n.title === "string" ? n.title : null,
    titleNative: typeof alt.ja === "string" && alt.ja ? alt.ja : null,
    year: yearOf(n.start_date),
    country: null,
    format: mediaType ? mediaType.toUpperCase() : null,
    status: statusOf(n.status, type),
    episodes: type === "anime" ? intOrNull(n.num_episodes) : null,
    chapters: type === "manga" ? intOrNull(n.num_chapters) : null,
    seasons: [],
    genres: ((n.genres ?? []) as Row[])
      .map((g) => (typeof g.name === "string" ? g.name : ""))
      .filter(Boolean)
      .slice(0, 8),
    tags: [],
    score: typeof n.mean === "number" ? Math.round(n.mean * 10) : null,
    posterUrl: n.main_picture?.large ?? n.main_picture?.medium ?? null,
    backdropUrl: null,
    synopsis: plainText(n.synopsis),
    // MAL's own adult signals: "black" nsfw or an Rx rating.
    adult: n.nsfw === "black" || n.rating === "rx",
    franchiseKey: null,
  };
}

/** One page of MAL's ranking for a kind; screen kinds are not served here. */
export async function discoverMal(
  clientId: string | undefined,
  kind: MediaKind,
  page: number,
): Promise<CatalogPage> {
  const r = ranking(kind);
  if (!r) return { items: [], hasNext: false };
  if (!clientId) throw new NotConfiguredError("mal");
  const u = new URL(`${API}/${r.type}/ranking`);
  u.searchParams.set("ranking_type", r.list);
  u.searchParams.set("limit", String(PER_PAGE));
  u.searchParams.set("offset", String((page - 1) * PER_PAGE));
  u.searchParams.set("fields", FIELDS);
  const body = (await fetchJson(u.toString(), {
    headers: { "X-MAL-CLIENT-ID": clientId },
  })) as Row | null;
  const items = ((body?.data ?? []) as Row[])
    .map((d) => d.node)
    .filter((n): n is Row => n != null && n.id != null)
    .map((n) => normalizeMal(n, r.type))
    .filter((i) => !i.adult && i.format !== "LIGHT_NOVEL" && i.format !== "NOVEL" && i.format !== "MUSIC");
  return { items, hasNext: Boolean(body?.paging?.next) };
}

/** MAL's search refuses queries under 3 characters and over 64. */
const MAL_Q_MIN = 3;
const MAL_Q_MAX = 64;

/** A MAL search hit: a catalog item plus MAL's other names for it. */
export type MalSearchItem = CatalogItem & { synonyms: string[] };

/** Cuts a name to MAL's 64-character limit at a word boundary when it can. */
export function malQuery(q: string): string | null {
  const s = q.trim().replace(/\s+/g, " ");
  if (s.length < MAL_Q_MIN) return null;
  if (s.length <= MAL_Q_MAX) return s;
  const cut = s.slice(0, MAL_Q_MAX);
  const space = cut.lastIndexOf(" ");
  return space >= MAL_Q_MIN ? cut.slice(0, space) : cut;
}

/**
 * MyAnimeList's title search for one name, as a second opinion when AniList
 * finds nothing. Adult entries, novels and music videos are dropped. Needs
 * only Cue's public client id.
 */
export async function searchMal(
  clientId: string | undefined,
  q: string,
  type: "anime" | "manga",
): Promise<MalSearchItem[]> {
  if (!clientId) throw new NotConfiguredError("mal");
  const query = malQuery(q);
  if (!query) return [];
  const u = new URL(`${API}/${type}`);
  u.searchParams.set("q", query);
  u.searchParams.set("limit", "6");
  u.searchParams.set("fields", FIELDS);
  u.searchParams.set("nsfw", "false");
  const body = (await fetchJson(u.toString(), {
    headers: { "X-MAL-CLIENT-ID": clientId },
  })) as Row | null;
  return ((body?.data ?? []) as Row[])
    .map((d) => d.node)
    .filter((n): n is Row => n != null && n.id != null)
    .map((n) => ({
      ...normalizeMal(n, type),
      synonyms: ((n.alternative_titles?.synonyms ?? []) as unknown[])
        .filter((s): s is string => typeof s === "string" && s.trim() !== "")
        .slice(0, 12),
    }))
    .filter((i) => !i.adult && i.format !== "LIGHT_NOVEL" && i.format !== "NOVEL" && i.format !== "MUSIC");
}
