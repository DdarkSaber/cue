import type { Context } from "hono";
import type { ContentfulStatusCode } from "hono/utils/http-status";

/** Error codes only. Responses never echo request values back. */
export type ErrorCode =
  | "invalid_request"
  | "not_found"
  | "not_implemented"
  | "not_configured"
  | "conflict"
  | "forbidden"
  | "upstream_error"
  | "token_expired"
  | "origin_not_allowed"
  | "payload_too_large"
  | "rate_limited"
  | "quota_exceeded"
  | "unavailable"
  | "internal";

export function fail(
  c: Context,
  status: ContentfulStatusCode,
  error: ErrorCode,
  extra: Record<string, unknown> = {},
) {
  return c.json({ error, ...extra }, status);
}
