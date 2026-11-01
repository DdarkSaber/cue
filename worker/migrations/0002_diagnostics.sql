-- Optional technical diagnostics, separate from encrypted sync.
-- Fixed seven-day session lifetime; only the capability digest is stored.
CREATE TABLE IF NOT EXISTS diagnostic_sessions (
  id TEXT PRIMARY KEY,
  events TEXT NOT NULL,
  revision INTEGER NOT NULL,
  last_write_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS diagnostic_sessions_expiry ON diagnostic_sessions(expires_at);
