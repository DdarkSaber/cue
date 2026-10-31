import { NotConfiguredError, UpstreamError } from "../catalog/types";
import { fetchJson } from "../catalog/upstream";
import type { Env } from "../env";

/**
 * One list entry as the app receives it from a sign-in or username import.
 * Tokens are forwarded once per request, never stored or logged.
 */
export interface ListEntry {
  malId: number | null;
  title: string;
  kind: "anime" | "manga" | "manhwa" | "manhua" | "series" | "movie" | null;
  status: string;
  score: number | null;
  scoreScale: string | null;
  progress: number | null;
  repeat: number | null;
  completedAt: string | null;
}

const MAX_ENTRIES = 20000;

type Row = Record<string, any>;

// --- MyAnimeList -------------------------------------------------------------

async function malPages(
  first: string,
  headers: Record<string, string>,
  type: "anime" | "manga",
): Promise<ListEntry[]> {
  const out: ListEntry[] = [];
  let url: string | null = first;
  // MAL paging links are followed only on the MAL API host.
  for (let page = 0; url && page < 20; page++) {
    const u = new URL(url);
    if (u.hostname !== "api.myanimelist.net") break;
    const body = (await fetchJson(url, { headers })) as Row | null;
    for (const d of body?.data ?? []) {
      const n = d.node ?? {};
      const s = d.list_status ?? {};
      out.push({
        malId: n.id ?? null,
        title: n.title ?? "",
        kind: type === "anime" ? "anime" : null,
        status: String(s.status ?? "").toLowerCase(),
        score: s.score > 0 ? s.score : null,
        scoreScale: s.score > 0 ? "10" : null,
        progress: (type === "anime" ? s.num_episodes_watched : s.num_chapters_read) || null,
        repeat: s.is_rewatching || s.num_times_rewatched > 0 ? Math.max(1, s.num_times_rewatched ?? 1) : null,
        completedAt: typeof s.finish_date === "string" && s.finish_date.length === 10 ? s.finish_date : null,
      });
      if (out.length >= MAX_ENTRIES) return out;
    }
    url = body?.paging?.next ?? null;
  }
  return out;
}

const MAL_FIELDS = "list_status{status,score,num_episodes_watched,num_chapters_read,is_rewatching,num_times_rewatched,finish_date}";

function malUrl(user: string, type: "anime" | "manga") {
  const u = new URL(`https://api.myanimelist.net/v2/users/${encodeURIComponent(user)}/${type}list`);
  u.searchParams.set("fields", MAL_FIELDS);
  u.searchParams.set("limit", "1000");
  u.searchParams.set("nsfw", "true");
  return u.toString();
}

/** A public MAL list by username; needs only Cue's client id. */
export async function malByUser(env: Env, name: string) {
  if (!env.MAL_CLIENT_ID) throw new NotConfiguredError("mal");
  const headers = { "X-MAL-CLIENT-ID": env.MAL_CLIENT_ID };
  const [a, m] = await Promise.all([
    malPages(malUrl(name, "anime"), headers, "anime"),
    malPages(malUrl(name, "manga"), headers, "manga"),
  ]);
  return [...a, ...m];
}

/** The signed-in person's MAL lists. */
export async function malViewer(token: string) {
  const headers = { Authorization: `Bearer ${token}` };
  const [a, m] = await Promise.all([
    malPages(malUrl("@me", "anime"), headers, "anime"),
    malPages(malUrl("@me", "manga"), headers, "manga"),
  ]);
  return [...a, ...m];
}

/** The signed-in MAL user's name, to show which account Cue is using. */
export async function malMe(token: string): Promise<string | null> {
  const me = (await fetchJson("https://api.myanimelist.net/v2/users/@me", {
    headers: { Authorization: `Bearer ${token}` },
  })) as Row | null;
  return typeof me?.name === "string" ? me.name : null;
}

// --- OAuth token exchange ----------------------------------------------------

export interface OAuthConfig {
  mal: string | null;
}

export function oauthConfig(env: Env): OAuthConfig {
  return {
    mal: env.MAL_CLIENT_ID || null,
  };
}

/** Exchanges an authorization code. Returns the access token only. */
export async function exchange(
  env: Env,
  provider: "mal",
  code: string,
  redirectUri: string,
  codeVerifier?: string,
): Promise<{ accessToken: string }> {
  const form = (o: Record<string, string | undefined>) => {
    const p = new URLSearchParams();
    for (const [k, v] of Object.entries(o)) if (v) p.set(k, v);
    return p;
  };
  let res: Row | null;
  switch (provider) {
    case "mal":
      if (!env.MAL_CLIENT_ID) throw new NotConfiguredError("mal");
      res = (await fetchJson("https://myanimelist.net/v1/oauth2/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: form({
          client_id: env.MAL_CLIENT_ID,
          client_secret: env.MAL_CLIENT_SECRET,
          grant_type: "authorization_code",
          code,
          redirect_uri: redirectUri,
          code_verifier: codeVerifier,
        }),
      })) as Row | null;
      break;
  }
  const token = res?.access_token;
  if (typeof token !== "string" || token.length === 0) throw new UpstreamError("token");
  return { accessToken: token };
}
