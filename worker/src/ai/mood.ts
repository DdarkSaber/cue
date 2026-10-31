import { NotConfiguredError, UpstreamError } from "../catalog/types";
import { UPSTREAM_TIMEOUT_MS } from "../catalog/upstream";
import type { Env } from "../env";

/**
 * Optional, opt-in mood hints: turns one typed sentence into feature names
 * the app already knows. Only the sentence and the app's own feature names
 * are sent; nothing about the person. Groq first, Gemini as a fallback.
 */
export interface MoodHints {
  features: string[];
  avoid: string[];
  provider: "groq" | "gemini";
}

type Row = Record<string, any>;

/** Defaults; override with GROQ_MODEL / GEMINI_MODEL vars when a model retires. */
export const GROQ_MODEL = "openai/gpt-oss-20b";
export const GEMINI_MODEL = "gemini-flash-lite-latest";

/** Like fetchJson, but a 404 is an error too (a retired model answers 404). */
async function post(url: string, headers: Record<string, string>, body: unknown): Promise<Row | null> {
  let res: Response;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...headers },
      body: JSON.stringify(body),
      redirect: "manual",
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS * 2),
    });
  } catch {
    throw new UpstreamError("fetch");
  }
  if (!res.ok) throw new UpstreamError(`status ${res.status}`);
  return (await res.json()) as Row;
}

const SYSTEM = `You map a person's short message about what they feel like watching or reading to tags.
Reply with JSON only: {"features": [...], "avoid": [...]}.
Use only names from the allowed list. At most 6 features and 4 avoid. Leave a list empty when unsure.`;

function prompt(text: string, allowed: string[]) {
  return `Allowed: ${allowed.join(", ")}\nMessage: ${text}`;
}

/** Keeps only allowed names, deduplicated and capped. */
export function cleanHints(raw: unknown, allowed: string[], cap: number): string[] {
  if (!Array.isArray(raw)) return [];
  const ok = new Set(allowed.map((a) => a.toLowerCase()));
  const out = new Set<string>();
  for (const r of raw) {
    const s = String(r).toLowerCase().trim();
    if (ok.has(s)) out.add(s);
    if (out.size >= cap) break;
  }
  return [...out];
}

function parse(text: unknown): Row | null {
  if (typeof text !== "string") return null;
  try {
    const j = JSON.parse(text);
    return j && typeof j === "object" ? (j as Row) : null;
  } catch {
    return null;
  }
}

async function groq(key: string, model: string, text: string, allowed: string[]): Promise<Row | null> {
  const body = await post("https://api.groq.com/openai/v1/chat/completions", { Authorization: `Bearer ${key}` }, {
      model,
      temperature: 0,
      max_tokens: 800,
      reasoning_effort: "low",
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: SYSTEM },
        { role: "user", content: prompt(text, allowed) },
      ],
  });
  return parse(body?.choices?.[0]?.message?.content);
}

async function gemini(key: string, model: string, text: string, allowed: string[]): Promise<Row | null> {
  const body = await post(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    { "x-goog-api-key": key },
    {
        systemInstruction: { parts: [{ text: SYSTEM }] },
        contents: [{ role: "user", parts: [{ text: prompt(text, allowed) }] }],
      generationConfig: { temperature: 0, maxOutputTokens: 400, responseMimeType: "application/json" },
    },
  );
  return parse(body?.candidates?.[0]?.content?.parts?.[0]?.text);
}

export async function moodHints(env: Env, text: string, allowed: string[]): Promise<MoodHints> {
  const tries: ["groq" | "gemini", () => Promise<Row | null>][] = [];
  if (env.GROQ_API_KEY) tries.push(["groq", () => groq(env.GROQ_API_KEY!, env.GROQ_MODEL ?? GROQ_MODEL, text, allowed)]);
  if (env.GEMINI_API_KEY) tries.push(["gemini", () => gemini(env.GEMINI_API_KEY!, env.GEMINI_MODEL ?? GEMINI_MODEL, text, allowed)]);
  if (tries.length === 0) throw new NotConfiguredError("ai");
  for (const [provider, run] of tries) {
    try {
      const j = await run();
      if (!j) {
        console.error(JSON.stringify({ e: "ai", p: provider, m: "unparsed" }));
        continue;
      }
      return {
        features: cleanHints(j.features, allowed, 6),
        avoid: cleanHints(j.avoid, allowed, 4),
        provider,
      };
    } catch (err) {
      // The provider name and a fixed reason or status only; never the text.
      console.error(JSON.stringify({ e: "ai", p: provider, m: (err as Error).message }));
    }
  }
  throw new UpstreamError("ai");
}
