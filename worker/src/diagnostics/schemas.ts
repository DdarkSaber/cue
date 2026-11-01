import { z } from "zod";

export const MAX_DIAGNOSTICS_BYTES = 6 * 1024;
export const diagnosticsId = z.string().regex(/^[a-f0-9]{64}$/);

/** Canonical unpadded base64url encoding of exactly 32 random bytes. */
export function diagnosticsToken(header: string | undefined): string | null {
  const match = /^Bearer ([A-Za-z0-9_-]{42}[AEIMQUYcgkosw048])$/.exec(header ?? "");
  return match?.[1] ?? null;
}

export const diagnosticEvent = z.strictObject({
  requestId: z.string().regex(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i)
    .transform((id) => id.toLowerCase()),
  appVersion: z.string().max(32).regex(/^\d+\.\d+\.\d+(?:\+\d+)?$/),
  provider: z.enum(["cue", "anilist", "mal", "local"]),
  operation: z.enum(["discover", "search", "title", "match", "aliases", "import", "settings", "mood"]),
  durationMs: z.number().int().min(0).max(120000),
  status: z.enum(["ok", "unavailable", "rejected", "failed"]),
  errorCode: z.enum([
    "none", "network", "http_4xx", "http_5xx", "rate_limited",
    "not_configured", "invalid_response", "storage_failed",
  ]),
});

export const diagnosticsBody = z.strictObject({
  events: z.array(diagnosticEvent).min(1).max(20),
});

export type DiagnosticEvent = z.infer<typeof diagnosticEvent>;
