import type { AliasCandidate } from "./mangadex";
import { type CatalogItem, intOrNull, plainText } from "./types";
import { fetchJson } from "./upstream";

/**
 * MangaUpdates (Baka-Updates) is the best source of Chinese, Korean and
 * Japanese alternate names ("associated names") for comics, including ones
 * AniList and MangaDex lack. Its search already matches associated names, and
 * its records carry a cover, genres and a rating, so a work that is on
 * neither AniList nor MangaDex can still get a card. Public, no key.
 */
const API = "https://api.mangaupdates.com/v1";

type Row = Record<string, any>;

/** MangaUpdates' type to a Cue kind. Novels and art books are not comics. */
function kindOf(type: unknown): CatalogItem["kind"] | null {
  switch (String(type ?? "").toLowerCase()) {
    case "manhua":
      return "manhua";
    case "manhwa":
      return "manhwa";
    case "manga":
    case "doujinshi":
    case "oel":
      return "manga";
    default:
      return null;
  }
}

const COUNTRY = { manhua: "CN", manhwa: "KR", manga: "JP" } as const;
const LANG = { manhua: "zh", manhwa: "ko", manga: "ja" } as const;

export function normalizeMangaUpdates(r: Row): CatalogItem | null {
  const kind = kindOf(r.type);
  if (!kind || !r.title || !r.series_id) return null;
  const genres: string[] = ((r.genres ?? []) as Row[])
    .map((g) => String(g.genre ?? ""))
    .filter(Boolean);
  const rating = Number(r.bayesian_rating);
  const status = String(r.status ?? "").toLowerCase();
  return {
    provider: "mangaupdates",
    providerId: String(r.series_id),
    providerKind: null,
    idMal: null,
    kind,
    titleEn: String(r.title),
    titleRomaji: null,
    titleNative: null,
    year: intOrNull(Number(r.year)),
    country: COUNTRY[kind as keyof typeof COUNTRY] ?? null,
    format: "MANGA",
    status: r.completed === true || status.includes("complete") ? "finished" : status ? "ongoing" : "unknown",
    episodes: null,
    chapters: intOrNull(Number(r.latest_chapter)),
    seasons: [],
    genres: genres.slice(0, 8),
    tags: [],
    score: rating > 0 ? Math.round(rating * 10) : null,
    posterUrl: typeof r.image?.url?.original === "string" ? r.image.url.original : null,
    backdropUrl: null,
    synopsis: plainText(r.description),
    adult: genres.some((g) => g === "Adult" || g === "Hentai"),
    franchiseKey: null,
  };
}

async function detail(id: string): Promise<Row | null> {
  return (await fetchJson(`${API}/series/${id}`)) as Row | null;
}

export async function titleMangaUpdates(id: string): Promise<CatalogItem | null> {
  const d = await detail(id);
  return d ? normalizeMangaUpdates(d) : null;
}

/**
 * The best MangaUpdates matches for a name, with every associated name. The
 * search matches associated names itself; fetching the top two series lets
 * the app confirm the typed name really is one of them.
 */
export async function aliasesFromMangaUpdates(q: string): Promise<AliasCandidate[]> {
  const found = (await fetchJson(`${API}/series/search`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ search: q, per_page: 3 }),
  })) as { results?: { record?: Row }[] } | null;
  const records = (found?.results ?? []).map((r) => r.record).filter((r): r is Row => !!r);
  const out: AliasCandidate[] = [];
  for (const rec of records.slice(0, 2)) {
    const d = await detail(String(rec.series_id));
    if (!d) continue;
    const item = normalizeMangaUpdates({ ...rec, ...d });
    if (!item) continue;
    const names = new Set<string>([String(d.title)]);
    for (const a of (d.associated ?? []) as Row[]) {
      if (typeof a.title === "string") names.add(a.title);
    }
    out.push({
      names: [...names].map((n) => n.trim().slice(0, 200)).filter(Boolean).slice(0, 60),
      al: null,
      mal: null,
      lang: LANG[item.kind as keyof typeof LANG] ?? null,
      item,
    });
  }
  return out;
}
