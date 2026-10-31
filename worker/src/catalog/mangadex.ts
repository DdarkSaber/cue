import type { CatalogItem } from "./types";
import { fetchJson } from "./upstream";

/**
 * MangaDex keeps many alternate names per comic (official, licensed,
 * romanised, fan) and links each to its AniList and MAL entries. Cue uses it
 * only to turn a name someone typed into an AniList id. It does not allow
 * browser calls, so this runs on the Worker. No key, no account.
 */
const API = "https://api.mangadex.org";

export interface AliasCandidate {
  /** Every title and alternate title, any language. */
  names: string[];
  /** AniList id, when MangaDex links one. */
  al: number | null;
  /** MyAnimeList id, when MangaDex links one. */
  mal: number | null;
  /** Original language, e.g. "ko", "zh", "ja". */
  lang: string | null;
  /** A ready card, when the source (MangaUpdates) can supply one. */
  item?: CatalogItem;
}

type Row = Record<string, any>;

function id(v: unknown): number | null {
  const n = Number(v);
  return Number.isInteger(n) && n > 0 ? n : null;
}

export function normalizeAlias(m: Row): AliasCandidate {
  const a: Row = m.attributes ?? {};
  const names = new Set<string>();
  for (const v of Object.values(a.title ?? {})) if (typeof v === "string") names.add(v);
  for (const alt of (a.altTitles ?? []) as Row[]) {
    for (const v of Object.values(alt)) if (typeof v === "string") names.add(v);
  }
  return {
    names: [...names].map((n) => n.trim().slice(0, 200)).filter(Boolean).slice(0, 40),
    al: id(a.links?.al),
    mal: id(a.links?.mal),
    lang: typeof a.originalLanguage === "string" ? a.originalLanguage : null,
  };
}

/** The best five MangaDex matches for a name, most relevant first. */
export async function aliasesFor(q: string): Promise<AliasCandidate[]> {
  const url = new URL(`${API}/manga`);
  url.searchParams.set("title", q);
  url.searchParams.set("limit", "5");
  url.searchParams.set("order[relevance]", "desc");
  const body = (await fetchJson(url.toString())) as { data?: Row[] } | null;
  return (body?.data ?? []).map(normalizeAlias);
}
