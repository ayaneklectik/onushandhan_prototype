CREATE TABLE test_seed_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  object_key TEXT NOT NULL UNIQUE,
  media_asset_id UUID NOT NULL UNIQUE REFERENCES media_assets(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE test_seed_articles (
  article_id UUID PRIMARY KEY REFERENCES articles(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  seed_version TEXT NOT NULL DEFAULT 'v1',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX test_seed_articles_category_id_idx ON test_seed_articles(category_id);
