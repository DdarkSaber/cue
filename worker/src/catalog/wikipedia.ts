import type { MediaKind } from "./types";
import { fetchJson } from "./upstream";

/**
 * English Wikipedia as a last resort for import matching: its search turns a
 * messy, translated or fan name into the article's canonical title, and the
 * article's redirects are the other names it is known by (romanized,
 * original, older licensed titles). Free, no key. Names only; nothing about
 * the person is sent.
 */
const API = "https://en.wikipedia.org/w/api.php";
const PAGES = 3;
const MAX_NAMES = 30;

/** One article: its title and the names that redirect to it. */
export interface WikiName {
  title: string;
  names: string[];
}

type Row = Record<string, any>;

/** A word that steers search to the right article for the kind. */
const HINT: Partial<Record<MediaKind, string>> = {
  anime: "anime",
  manga: "manga",
  manhwa: "manhwa",
  manhua: "manhua",
};

/** "Monster (manga)" and "Pluto (2023 TV series)" lose the disambiguator. */
export function plainTitle(t: string): string {
  return t.replace(/\s*\([^)]*\)\s*$/, "").trim();
}

export function normalizeWiki(body: Row | null): WikiName[] {
  const pages = ((body?.query?.pages ?? []) as Row[])
    .filter((p) => typeof p.title === "string" && p.missing !== true)
    .filter((p) => p.pageprops?.disambiguation === undefined)
    .filter((p) => !/^List of /i.test(p.title))
    .sort((a, b) => (Number(a.index) || 99) - (Number(b.index) || 99));
  return pages.slice(0, PAGES).map((p) => {
    const title = plainTitle(p.title as string);
    const names = new Set<string>();
    for (const r of (p.redirects ?? []) as Row[]) {
      if (typeof r.title !== "string") continue;
      const n = plainTitle(r.title).slice(0, 200);
      if (n && n.toLowerCase() !== title.toLowerCase()) names.add(n);
    }
    return { title: title.slice(0, 200), names: [...names].slice(0, MAX_NAMES) };
  });
}

/** The best few articles for a name, most relevant first. */
export async function wikiNames(q: string, kind: MediaKind | undefined): Promise<WikiName[]> {
  const hint = kind ? HINT[kind] : undefined;
  const u = new URL(API);
  const params: Record<string, string> = {
    action: "query",
    format: "json",
    formatversion: "2",
    generator: "search",
    gsrsearch: hint ? `${q} ${hint}` : q,
    gsrnamespace: "0",
    gsrlimit: String(PAGES + 1),
    prop: "redirects|pageprops",
    ppprop: "disambiguation",
    rdprop: "title",
    rdnamespace: "0",
    rdlimit: "max",
  };
  for (const [k, v] of Object.entries(params)) u.searchParams.set(k, v);
  return normalizeWiki((await fetchJson(u.toString())) as Row | null);
}
