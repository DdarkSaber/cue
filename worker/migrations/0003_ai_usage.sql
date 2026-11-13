-- AI calls per UTC day: one global row keyed by day ("2026-11-13") and one row
-- per client keyed by day plus a short hash ("2026-11-13|<16 hex>"). No raw IPs.
-- Kept in D1 so catalog cache writes cannot use up the counter's KV writes.
CREATE TABLE IF NOT EXISTS ai_usage (
  day TEXT PRIMARY KEY,
  used INTEGER NOT NULL
);
