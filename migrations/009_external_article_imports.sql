CREATE TABLE IF NOT EXISTS external_article_imports (
  article_id UUID PRIMARY KEY REFERENCES articles(id) ON DELETE CASCADE,
  source_url TEXT NOT NULL UNIQUE,
  source_name TEXT NOT NULL DEFAULT '24GhontaTV',
  batch_key TEXT NOT NULL,
  source_published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS external_article_imports_batch_key_idx
  ON external_article_imports(batch_key);
