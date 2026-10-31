import type { z } from "zod";

import type { mood as moodSchema } from "../schemas";
import {
  type CatalogItem,
  type CatalogPage,
  type MediaKind,
  intOrNull,
  plainText,
} from "./types";
import { fetchJson } from "./upstream";

const ENDPOINT = "https://graphql.anilist.co";
export const ANILIST_KINDS = new Set<MediaKind>([
  "anime",
  "manga",
  "manhwa",
  "manhua",
]);

/** Mood to AniList genres. Fixed sets; the ranker refines with tags. */
export const MOOD_GENRES: Record<z.infer<typeof moodSchema>, string[]> = {
  hype: ["Action", "Sports"],
  comfort: ["Slice of Life", "Comedy"],
  gripping: ["Thriller", "Mystery", "Psychological"],
  feels: ["Romance", "Drama"],
};

const FIELDS = `
  id idMal type format status episodes chapters countryOfOrigin isAdult
  averageScore genres startDate { year }
  title { romaji english native }
  coverImage { extraLarge large }
  bannerImage
  description(asHtml: false)
  tags { name rank isAdult isMediaSpoiler }
`;

// Fixed queries. Clients never send GraphQL; they pick from these.
const DISCOVER = `query ($page: Int, $type: MediaType, $country: CountryCode, $genres: [String], $notFormats: [MediaFormat]) {
  Page(page: $page, perPage: 50) {
    pageInfo { hasNextPage }
    media(type: $type, countryOfOrigin: $country, genre_in: $genres, format_not_in: $notFormats, isAdult: false, sort: [POPULARITY_DESC]) { ${FIELDS} }
  }
}`;

const TITLE = `query ($id: Int) {
  Media(id: $id) {
    ${FIELDS}
    relations { edges { relationType node { id type } } }
  }
}`;

const SEARCH = `query ($q: String, $type: MediaType, $country: CountryCode) {
  Page(page: 1, perPage: 10) {
    media(search: $q, type: $type, countryOfOrigin: $country, isAdult: false) { ${FIELDS} }
  }
}`;

interface KindQuery {
  type: "ANIME" | "MANGA";
  country?: string;
  notFormats: string[];
}

function kindQuery(kind: MediaKind): KindQuery {
  switch (kind) {
    case "anime":
      return { type: "ANIME", notFormats: ["MUSIC"] };
    case "manhwa":
      return { type: "MANGA", country: "KR", notFormats: ["NOVEL"] };
    case "manhua":
      return { type: "MANGA", country: "CN", notFormats: ["NOVEL"] };
    default:
      return { type: "MANGA", country: "JP", notFormats: ["NOVEL"] };
  }
}

async function query(q: string, variables: Record<string, unknown>) {
  const body = (await fetchJson(ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify({ query: q, variables }),
  })) as { data?: Record<string, unknown> } | null;
  return body?.data ?? null;
}

type Media = Record<string, any>;

function kindOf(m: Media): MediaKind {
  if (m.type === "ANIME") return "anime";
  if (m.countryOfOrigin === "KR") return "manhwa";
  if (m.countryOfOrigin === "CN" || m.countryOfOrigin === "TW") return "manhua";
  return "manga";
}

function statusOf(m: Media): CatalogItem["status"] {
  switch (m.status) {
    case "FINISHED":
      return "finished";
    case "RELEASING":
      return m.type === "ANIME" ? "airing" : "ongoing";
    case "HIATUS":
      return "ongoing";
    default:
      return "unknown";
  }
}

export function normalizeAniList(m: Media): CatalogItem {
  const tags: Media[] = Array.isArray(m.tags) ? m.tags : [];
  const relations: Media[] = m.relations?.edges ?? [];
  const franchise = relations
    .filter(
      (e) =>
        (e.relationType === "PREQUEL" || e.relationType === "PARENT") &&
        e.node?.type === m.type,
    )
    .map((e) => Number(e.node.id))
    .concat(Number(m.id))
    .reduce((a, b) => Math.min(a, b));
  return {
    provider: "anilist",
    providerId: String(m.id),
    providerKind: null,
    idMal: intOrNull(m.idMal),
    kind: kindOf(m),
    titleEn: m.title?.english ?? null,
    titleRomaji: m.title?.romaji ?? null,
    titleNative: m.title?.native ?? null,
    year: intOrNull(m.startDate?.year),
    country: m.countryOfOrigin ?? null,
    format: m.format ?? null,
    status: statusOf(m),
    episodes: intOrNull(m.episodes),
    chapters: intOrNull(m.chapters),
    seasons: [],
    genres: Array.isArray(m.genres) ? m.genres.slice(0, 8) : [],
    tags: tags
      .filter((t) => !t.isMediaSpoiler && (t.rank ?? 0) >= 60)
      .slice(0, 12)
      .map((t) => String(t.name).toLowerCase()),
    score: intOrNull(m.averageScore),
    posterUrl: m.coverImage?.extraLarge ?? m.coverImage?.large ?? null,
    backdropUrl: m.bannerImage ?? null,
    synopsis: plainText(m.description),
    adult: Boolean(m.isAdult) || tags.some((t) => t.isAdult),
    franchiseKey: relations.length ? `anilist:${franchise}` : null,
  };
}

export async function discoverAniList(
  kind: MediaKind,
  mood: keyof typeof MOOD_GENRES | undefined,
  page: number,
): Promise<CatalogPage> {
  const k = kindQuery(kind);
  const data = await query(DISCOVER, {
    page,
    type: k.type,
    country: k.country,
    notFormats: k.notFormats,
    genres: mood ? MOOD_GENRES[mood] : undefined,
  });
  const p = data?.Page as Media | undefined;
  return {
    items: ((p?.media as Media[]) ?? []).map(normalizeAniList),
    hasNext: Boolean(p?.pageInfo?.hasNextPage),
  };
}

export async function titleAniList(id: string): Promise<CatalogItem | null> {
  const data = await query(TITLE, { id: Number(id) });
  const m = data?.Media as Media | undefined;
  return m ? normalizeAniList(m) : null;
}

export async function searchAniList(
  q: string,
  kind: MediaKind | undefined,
): Promise<CatalogItem[]> {
  const k = kind ? kindQuery(kind) : undefined;
  const data = await query(SEARCH, {
    q,
    type: k?.type,
    country: kind && kind !== "anime" ? k?.country : undefined,
  });
  const p = data?.Page as Media | undefined;
  return ((p?.media as Media[]) ?? []).map(normalizeAniList);
}

const BY_MAL = `query ($ids: [Int], $type: MediaType) {
  Page(page: 1, perPage: 50) {
    media(idMal_in: $ids, type: $type) { ${FIELDS} }
  }
}`;

/** Titles by MAL id, 50 per call. Unknown ids are simply absent. */
export async function byMalIds(
  ids: number[],
  type: "ANIME" | "MANGA",
): Promise<CatalogItem[]> {
  if (ids.length === 0) return [];
  const data = await query(BY_MAL, { ids: ids.slice(0, 50), type });
  const p = data?.Page as Media | undefined;
  return ((p?.media as Media[]) ?? []).map(normalizeAniList);
}

/**
 * Several title searches in one request. The query text is built only from
 * fixed fragments and numbered aliases; titles travel as variables.
 */
export async function searchManyAniList(
  items: { q: string; kind?: MediaKind }[],
): Promise<CatalogItem[][]> {
  if (items.length === 0) return [];
  const vars: Record<string, unknown> = {};
  const decls: string[] = [];
  const parts: string[] = [];
  items.forEach((it, i) => {
    const k = it.kind && ANILIST_KINDS.has(it.kind) ? kindQuery(it.kind) : undefined;
    vars[`q${i}`] = it.q;
    decls.push(`$q${i}: String`);
    const typeArg = k ? `, type: ${k.type}` : "";
    const countryArg = k?.country && it.kind !== "anime" ? `, countryOfOrigin: ${k.country}` : "";
    parts.push(
      `s${i}: Page(page: 1, perPage: 3) { media(search: $q${i}${typeArg}${countryArg}, isAdult: false) { ${FIELDS} } }`,
    );
  });
  const q = `query (${decls.join(", ")}) { ${parts.join(" ")} }`;
  const data = await query(q, vars);
  return items.map((_, i) => {
    const page = data?.[`s${i}`] as Media | undefined;
    return ((page?.media as Media[]) ?? []).map(normalizeAniList);
  });
}
