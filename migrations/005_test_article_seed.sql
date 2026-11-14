CREATE TABLE test_seeded_articles (
  article_id UUID PRIMARY KEY REFERENCES articles(id) ON DELETE CASCADE,
  seed_key TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX test_seeded_articles_created_at_idx
  ON test_seeded_articles(created_at DESC);
