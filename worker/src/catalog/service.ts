import type { Env } from "../env";
import {
  ANILIST_KINDS,
  discoverAniList,
  searchAniList,
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
