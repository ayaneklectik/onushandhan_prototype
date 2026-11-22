ALTER TABLE categories
  ADD COLUMN nav_sort_order INTEGER NOT NULL DEFAULT 1000,
  ADD COLUMN homepage_sort_order INTEGER NOT NULL DEFAULT 1000,
  ADD COLUMN homepage_layout TEXT NOT NULL DEFAULT 'lead-headlines'
    CHECK (homepage_layout IN ('lead-headlines', 'feature-headlines', 'image-grid', 'headline-list'));

WITH ordered AS (
  SELECT id, row_number() OVER (ORDER BY parent_id NULLS FIRST, parent_id, name, id) - 1 AS sort_order
  FROM categories
)
UPDATE categories AS category
SET nav_sort_order = ordered.sort_order
FROM ordered
WHERE category.id = ordered.id;

WITH ordered AS (
  SELECT id, row_number() OVER (ORDER BY name, id) - 1 AS sort_order
  FROM categories
  WHERE parent_id IS NULL
)
UPDATE categories AS category
SET homepage_sort_order = ordered.sort_order
FROM ordered
WHERE category.id = ordered.id;

UPDATE categories
SET homepage_layout = CASE slug
  WHEN 'corruption' THEN 'image-grid'
  WHEN 'power-and-influence' THEN 'feature-headlines'
  WHEN 'organized-crime' THEN 'headline-list'
  WHEN 'opinion' THEN 'feature-headlines'
  WHEN 'freedom-and-repression' THEN 'image-grid'
  WHEN 'reports' THEN 'lead-headlines'
  WHEN 'video-podcast' THEN 'headline-list'
  ELSE 'lead-headlines'
END;
