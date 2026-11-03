import { z } from "zod";

import { NotConfiguredError, UpstreamError } from "../catalog/types";
import type { Env } from "../env";
import { sha256Hex } from "../sync/store";
import { GEMINI_MODEL, GROQ_MODEL, parse, post } from "./mood";

/**
 * Optional, opt-in taste picks: a compact list of titles the person liked and
 * disliked goes in; title suggestions that each cite one liked title come out.
 * Titles are sent to the AI provider for this request only and are never
 * logged. The cache key is a hash of the profile, never the titles.
 */
const kinds = z.enum(["anime", "manga", "manhwa", "manhua", "kdrama", "cdrama", "jdrama", "series", "movie"]);
const title = z.string().trim().min(1).max(100);
const year = z.number().int().min(1900).max(2100).optional();

export const recommendBody = z.object({
  liked: z
    .array(
      z.object({
        title,
        kind: kinds,
        year,
        /** Optional 0-10 rating the person gave. */
        rating: z.number().min(0).max(10).optional(),
      }),
    )
    .min(1)
    .max(25),
  disliked: z.array(z.object({ title, kind: kinds.optional() })).max(10).default([]),
  kinds: z.array(kinds).min(1).max(9),
  mood: z.string().trim().min(1).max(200).optional(),
});
export type RecommendBody = z.infer<typeof recommendBody>;

export interface Suggestion {
  title: string;
  kind: z.infer<typeof kinds>;
  year?: number;
  because: string;
  why: string;
}
export interface Recommendations {
  suggestions: Suggestion[];
  provider: "groq" | "gemini";
}

export const MAX_SUGGESTIONS = 30;
/** A few hours: picks should feel fresh but a re-open must not respend quota. */
export const CACHE_TTL_SECONDS = 6 * 60 * 60;

type Row = Record<string, any>;

const SYSTEM = `You recommend anime, manga, manhwa, manhua, dramas, series and movies to one person from titles they liked.
Reply with JSON only: {"suggestions":[{"title":"","kind":"","year":0,"because":"","why":""}]}.
Rules: at most 30 suggestions. Only real, existing works; never invent titles. Never suggest a title from the liked or disliked lists.
"kind" must be one of the enabled kinds. "because" must be copied exactly from one liked title. "why" is one short sentence (under 100 characters) about what they share.
Prefer variety across the liked titles. Avoid things similar to the disliked ones. Omit "year" when unsure.`;

function prompt(p: RecommendBody) {
  const liked = p.liked
    .map((l) => `- ${l.title} (${l.kind}${l.year ? ` ${l.year}` : ""}${l.rating != null ? `, rated ${l.rating}/10` : ""})`)
    .join("\n");
  const disliked = p.disliked.map((d) => `- ${d.title}`).join("\n") || "- none";
  return `Enabled kinds: ${p.kinds.join(", ")}\nLiked:\n${liked}\nDisliked:\n${disliked}${p.mood ? `\nMood: ${p.mood}` : ""}`;
}

const norm = (s: string) => s.toLowerCase().replace(/\s+/g, " ").trim();

/** Keeps well-formed items whose `because` is a liked title; dedupes; caps. */
export function cleanSuggestions(raw: unknown, p: RecommendBody): Suggestion[] {
  if (!Array.isArray(raw)) return [];
  const likedByName = new Map(p.liked.map((l) => [norm(l.title), l.title]));
  const banned = new Set([...p.liked, ...p.disliked].map((t) => norm(t.title)));
  const enabled = new Set<string>(p.kinds);
  const seen = new Set<string>();
  const out: Suggestion[] = [];
  for (const r of raw) {
    if (!r || typeof r !== "object") continue;
    const { title: t, kind, year: y, because, why } = r as Row;
    if (typeof t !== "string" || typeof because !== "string" || typeof why !== "string") continue;
    const name = t.trim();
    const cite = likedByName.get(norm(because));
    const reason = why.trim().replace(/\s+/g, " ");
    if (!name || name.length > 100 || !cite || !reason) continue;
    if (typeof kind !== "string" || !enabled.has(kind)) continue;
    if (banned.has(norm(name)) || seen.has(`${kind}:${norm(name)}`)) continue;
    seen.add(`${kind}:${norm(name)}`);
    const item: Suggestion = {
      title: name,
      kind: kind as Suggestion["kind"],
      because: cite,
      why: reason.slice(0, 160),
    };
    if (typeof y === "number" && Number.isInteger(y) && y >= 1900 && y <= 2100) item.year = y;
    out.push(item);
    if (out.length >= MAX_SUGGESTIONS) break;
  }
  return out;
}

async function groq(key: string, model: string, p: RecommendBody): Promise<Row | null> {
  const body = await post("https://api.groq.com/openai/v1/chat/completions", { Authorization: `Bearer ${key}` }, {
    model,
    temperature: 0.4,
    max_tokens: 3500,
    reasoning_effort: "low",
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: SYSTEM },
      { role: "user", content: prompt(p) },
    ],
  });
  return parse(body?.choices?.[0]?.message?.content);
}

async function gemini(key: string, model: string, p: RecommendBody): Promise<Row | null> {
  const body = await post(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    { "x-goog-api-key": key },
    {
      systemInstruction: { parts: [{ text: SYSTEM }] },
      contents: [{ role: "user", parts: [{ text: prompt(p) }] }],
      generationConfig: { temperature: 0.4, maxOutputTokens: 3500, responseMimeType: "application/json" },
    },
  );
  return parse(body?.candidates?.[0]?.content?.parts?.[0]?.text);
}

/** Stable key: order of liked/kinds does not matter; titles are hashed, not stored. */
export async function profileKey(p: RecommendBody): Promise<string> {
  const canon = JSON.stringify([
    p.liked.map((l) => [norm(l.title), l.kind, l.year ?? 0, l.rating ?? -1]).sort(),
    p.disliked.map((d) => [norm(d.title), d.kind ?? ""]).sort(),
    [...p.kinds].sort(),
    p.mood ? norm(p.mood) : "",
  ]);
  return `ai:rec:${(await sha256Hex(canon)).slice(0, 40)}`;
}

export function hasAiKeys(env: Env) {
  return Boolean(env.GROQ_API_KEY || env.GEMINI_API_KEY);
}

export async function cachedRecommendations(kv: KVNamespace, key: string): Promise<Recommendations | null> {
  try {
    const hit = (await kv.get(key, "json")) as Recommendations | null;
    return hit && Array.isArray(hit.suggestions) ? hit : null;
  } catch {
    return null;
  }
}

export async function storeRecommendations(kv: KVNamespace, key: string, value: Recommendations) {
  try {
    await kv.put(key, JSON.stringify(value), { expirationTtl: CACHE_TTL_SECONDS });
  } catch {
    // A cache failure must not fail the request.
  }
}

export async function recommend(env: Env, p: RecommendBody): Promise<Recommendations> {
  const tries: ["groq" | "gemini", () => Promise<Row | null>][] = [];
  if (env.GROQ_API_KEY) tries.push(["groq", () => groq(env.GROQ_API_KEY!, env.GROQ_MODEL ?? GROQ_MODEL, p)]);
  if (env.GEMINI_API_KEY) tries.push(["gemini", () => gemini(env.GEMINI_API_KEY!, env.GEMINI_MODEL ?? GEMINI_MODEL, p)]);
  if (tries.length === 0) throw new NotConfiguredError("ai");
  for (const [provider, run] of tries) {
    try {
      const j = await run();
      const suggestions = j ? cleanSuggestions(j.suggestions, p) : [];
      if (suggestions.length === 0) {
        console.error(JSON.stringify({ e: "ai", p: provider, m: j ? "empty" : "unparsed" }));
        continue;
      }
      return { suggestions, provider };
    } catch (err) {
      // Provider and a fixed reason or status only; never titles.
      console.error(JSON.stringify({ e: "ai", p: provider, m: (err as Error).message }));
    }
  }
  throw new UpstreamError("ai");
}
