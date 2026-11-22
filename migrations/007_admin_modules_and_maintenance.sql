CREATE TABLE IF NOT EXISTS admin_content_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  module TEXT NOT NULL CHECK (module IN ('writings', 'ads')),
  title TEXT NOT NULL,
  content TEXT NOT NULL DEFAULT '',
  target_url TEXT NOT NULL DEFAULT '',
  image_url TEXT NOT NULL DEFAULT '',
  placement TEXT NOT NULL DEFAULT '',
  is_enabled BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS admin_content_entries_module_idx
  ON admin_content_entries(module, sort_order, created_at DESC);

CREATE TABLE IF NOT EXISTS article_placements (
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  placement TEXT NOT NULL CHECK (placement IN ('top', 'recent', 'breaking', 'popular', 'special')),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (article_id, placement)
);
CREATE INDEX IF NOT EXISTS article_placements_placement_idx
  ON article_placements(placement, sort_order);

INSERT INTO site_settings (setting_key, setting_value)
VALUES ('maintenance_mode', 'false')
ON CONFLICT (setting_key) DO NOTHING;
