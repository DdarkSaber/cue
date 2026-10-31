import type { Env } from "../env";
import {
  ANILIST_KINDS,
  byMalIds,
  discoverAniList,
  searchAniList,
  searchManyAniList,
  titleAniList,
} from "./anilist";
import { TTL, cached } from "./cache";
import {
  type TmdbType,
  discoverTmdb,
  providersTmdb,
  searchTmdb,
  titleTmdb,
} from "./tmdb";
import { searchTvmaze, titleTvmaze } from "./tvmaze";
import type { CatalogItem, CatalogPage, CatalogProvider, MediaKind } from "./types";

type Mood = "hype" | "comfort" | "gripping" | "feels";

export function discover(env: Env, kind: MediaKind, mood: Mood | undefined, page: number) {
  return cached<CatalogPage>(
    env.CATALOG_CACHE,
    `discover:${kind}:${mood ?? "-"}:${page}`,
    TTL.discover,
    () =>
      ANILIST_KINDS.has(kind)
        ? discoverAniList(kind, mood, page)
        : discoverTmdb(env.TMDB_API_KEY, kind, mood, page),
  );
}

export function title(env: Env, provider: CatalogProvider, id: string, type: TmdbType) {
  return cached<CatalogItem | null>(
    env.CATALOG_CACHE,
    `title:${provider}:${provider === "tmdb" ? type : "-"}:${id}`,
    TTL.title,
    () => {
      switch (provider) {
        case "anilist":
          return titleAniList(id);
        case "tmdb":
          return titleTmdb(env.TMDB_API_KEY, id, type);
        case "tvmaze":
          return titleTvmaze(id);
      }
    },
  );
}

/**
 * Match candidates for imports. Anime and reading go to AniList; dramas,
 * series and movies go to TMDB when keyed, else TVmaze (series only).
 * With no kind, both sides are asked.
 */
export function search(env: Env, q: string, kind: MediaKind | undefined) {
  const norm = q.toLowerCase().replace(/\s+/g, " ");
  return cached<CatalogItem[]>(
    env.CATALOG_CACHE,
    `search:${kind ?? "-"}:${norm}`,
    TTL.search,
    async () => {
      const screen = async () => {
        if (kind === "movie" && !env.TMDB_API_KEY) return [];
        return env.TMDB_API_KEY ? searchTmdb(env.TMDB_API_KEY, q, kind) : searchTvmaze(q);
      };
      if (kind && ANILIST_KINDS.has(kind)) return searchAniList(q, kind);
      if (kind) return screen();
      const [a, b] = await Promise.allSettled([searchAniList(q, undefined), screen()]);
      return [
        ...(a.status === "fulfilled" ? a.value.slice(0, 6) : []),
        ...(b.status === "fulfilled" ? b.value.slice(0, 6) : []),
      ];
    },
  );
}

export function providers(env: Env, id: string, type: TmdbType, region: string) {
  return cached(
    env.CATALOG_CACHE,
    `providers:${type}:${id}:${region}`,
    TTL.providers,
    () => providersTmdb(env.TMDB_API_KEY, id, type, region),
  );
}

/**
 * Batch match for imports. Reading and anime titles go to AniList in one
 * aliased query; screen titles go to TMDB (if keyed) or TVmaze one by one,
 * staying well under the per-request subrequest limit.
 */
export async function match(
  env: Env,
  items: { q: string; kind?: MediaKind }[],
  malAnime: number[],
  malManga: number[],
) {
  const isScreen = (k?: MediaKind) => !!k && !ANILIST_KINDS.has(k);
  const aniIdx = items.map((it, i) => (isScreen(it.kind) ? -1 : i)).filter((i) => i >= 0);
  const screenIdx = items.map((it, i) => (isScreen(it.kind) || !it.kind ? i : -1)).filter((i) => i >= 0);
  const results: CatalogItem[][] = items.map(() => []);

  const [ani, malA, malM] = await Promise.all([
    searchManyAniList(aniIdx.map((i) => items[i]!)),
    byMalIds(malAnime, "ANIME"),
    byMalIds(malManga, "MANGA"),
  ]);
  aniIdx.forEach((i, j) => results[i]!.push(...(ani[j] ?? [])));

  for (const i of screenIdx) {
    const it = items[i]!;
    if (it.kind === "movie" && !env.TMDB_API_KEY) continue;
    try {
      const found = env.TMDB_API_KEY
        ? await searchTmdb(env.TMDB_API_KEY, it.q, it.kind)
        : await searchTvmaze(it.q);
      results[i]!.push(...found.slice(0, 4));
    } catch {
      // One failed lookup leaves that title unresolved, not the batch.
    }
  }
  return { results, mal: [...malA, ...malM] };
}
