-- Encrypted sync blobs (M8). Plaintext never reaches the Worker.
CREATE TABLE IF NOT EXISTS sync_blobs (
  id TEXT PRIMARY KEY,
  token_hash TEXT NOT NULL,
  version INTEGER NOT NULL,
  data TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
