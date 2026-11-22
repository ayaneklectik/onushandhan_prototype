import { randomUUID } from "node:crypto";
import bcrypt from "bcryptjs";
import express from "express";
import { z } from "zod";
import { pool, recordActivity } from "./db.js";
import { requireAuth, requireRoles } from "./auth.js";
import { mediaUrl, validYoutubeVideoUrl, youtubeVideoId } from "./media.js";

export const api = express.Router();
const SUPER = "super_admin";
const EDITORS = ["super_admin", "admin", "moderator"];
const MANAGERS = ["super_admin", "admin"];
const text = (max) => z.string().trim().max(max);
const uuid = z.uuid();

api.param("id", (req, res, next, id) => {
  if (!uuid.safeParse(id).success) {
    return res.status(400).json({ error: "Invalid record ID." });
  }
  return next();
});

function invalid(res, error) {
  return res.status(400).json({
    error: "Invalid request data.",
    details: error.issues.map((issue) => ({ field: issue.path.join("."), message: issue.message })),
  });
}

function parse(schema, input, res) {
  const result = schema.safeParse(input);
  if (!result.success) {
    invalid(res, result.error);
    return null;
  }
  return result.data;
}

function slugify(value) {
  return value
    .normalize("NFKD")
    .toLowerCase()
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 100);
}

async function uniqueArticleSlug(client, title) {
  const base = slugify(title) || `news-${randomUUID().slice(0, 8)}`;
  let slug = base;
  for (let index = 2; ; index += 1) {
    const exists = await client.query("SELECT 1 FROM articles WHERE slug = $1", [slug]);
    if (!exists.rowCount) return slug;
    slug = `${base}-${index}`;
  }
}

async function articleRecord(client, id) {
  const result = await client.query(
    `SELECT a.id, a.slug, a.title, a.headline, a.summary, a.body, a.image_key,
            a.image_alt, a.attribution, a.image_caption, a.image_credit, a.category_id, a.status, a.author_id, a.published_at,
            a.created_at, a.updated_at, u.username AS author,
            c.name AS category, c.slug AS category_slug, c.parent_id AS category_parent_id
     FROM articles a
     JOIN users u ON u.id = a.author_id
     LEFT JOIN categories c ON c.id = a.category_id
     WHERE a.id = $1`,
    [id],
  );
  const row = result.rows[0];
  if (row) row.image_url = mediaUrl(row.image_key);
  return row;
}

async function assertMedia(client, key, type, user) {
  if (!key) return;
  const result = await client.query(
    `SELECT 1 FROM media_assets
     WHERE object_key = $1 AND media_type = $2 AND status = 'ready'
       AND ($3::text <> 'moderator' OR uploader_id = $4)`,
    [key, type, user.role, user.id],
  );
  if (!result.rowCount) {
    const error = new Error("Media must be fully uploaded before it can be attached.");
    error.status = 400;
    throw error;
  }
}

async function assertCategory(client, id, allowExistingVideoCategory = false) {
  if (!id) return;
  const result = await client.query(
    `SELECT c.id, c.slug, c.is_enabled, parent.is_enabled AS parent_enabled
     FROM categories c LEFT JOIN categories parent ON parent.id = c.parent_id
     WHERE c.id = $1`,
    [id],
  );
  if (!result.rowCount || !result.rows[0].is_enabled || result.rows[0].parent_enabled === false) {
    const error = new Error("Choose an enabled category.");
    error.status = 400;
    throw error;
  }
  if (result.rows[0].slug === "video-podcast" && !allowExistingVideoCategory) {
    const error = new Error("The video podcast category is for videos only. Choose a news category for this article.");
    error.status = 400;
    throw error;
  }
}

async function assertArticlePermission(client, id, user, action = "edit") {
  const result = await client.query("SELECT id, author_id, status, category_id FROM articles WHERE id = $1", [id]);
  const article = result.rows[0];
  if (!article) return { error: "Article not found.", status: 404 };
  if (user.role === "moderator") {
    if (article.author_id !== user.id) return { error: "You can only manage your own articles.", status: 403 };
    if (action !== "edit" || article.status !== "draft") {
      return { error: "Moderators can only edit their own draft articles.", status: 403 };
    }
  }
  return { article };
}

async function assertVideoPermission(client, id, user, action = "edit") {
  const result = await client.query("SELECT id, author_id, status FROM videos WHERE id = $1", [id]);
  const video = result.rows[0];
  if (!video) return { error: "Video not found.", status: 404 };
  if (user.role === "moderator") {
    if (video.author_id !== user.id) return { error: "You can only manage your own videos.", status: 403 };
    if (action !== "edit" || video.status !== "draft") {
      return { error: "Moderators can only edit their own draft videos.", status: 403 };
    }
  }
  return { video };
}

api.get("/public/site", async (_req, res) => {
  const categoriesResult = await pool.query(
    `SELECT c.id, c.name, c.slug, c.parent_id, c.nav_sort_order,
            c.homepage_sort_order, c.homepage_layout
     FROM categories c LEFT JOIN categories parent ON parent.id = c.parent_id
     WHERE c.is_enabled = true AND (c.parent_id IS NULL OR parent.is_enabled = true)
     ORDER BY c.nav_sort_order, c.id`,
  );
  const articlesResult = await pool.query(
    `SELECT a.id, a.slug, a.title, a.headline, a.summary, a.image_key, a.image_alt,
            a.category_id, a.published_at, u.username AS author,
            c.name AS category, c.slug AS category_slug
     FROM articles a
     JOIN users u ON u.id = a.author_id
     LEFT JOIN categories c ON c.id = a.category_id
     LEFT JOIN categories parent ON parent.id = c.parent_id
     WHERE a.status = 'published'
       AND c.slug IS DISTINCT FROM 'video-podcast'
       AND (c.id IS NULL OR (c.is_enabled = true AND (c.parent_id IS NULL OR parent.is_enabled = true)))
     ORDER BY a.published_at DESC`,
  );
  const sectionsResult = await pool.query(
    `SELECT s.id, s.slug, s.title, s.description, s.sort_order,
            COALESCE(
              json_agg(json_build_object(
                'id', a.id, 'slug', a.slug, 'title', a.title, 'headline', a.headline,
                'summary', a.summary, 'imageKey', a.image_key, 'imageAlt', a.image_alt,
                'categoryId', a.category_id, 'publishedAt', a.published_at
              ) ORDER BY sa.sort_order)
              FILTER (WHERE a.id IS NOT NULL AND a.status = 'published'
                AND c.slug IS DISTINCT FROM 'video-podcast'
                AND (c.id IS NULL OR (c.is_enabled = true AND (c.parent_id IS NULL OR parent.is_enabled = true)))),
              '[]'::json
            ) AS articles
     FROM site_sections s
     LEFT JOIN section_articles sa ON sa.section_id = s.id
     LEFT JOIN articles a ON a.id = sa.article_id
     LEFT JOIN categories c ON c.id = a.category_id
     LEFT JOIN categories parent ON parent.id = c.parent_id
     WHERE s.is_enabled = true
     GROUP BY s.id
     ORDER BY s.sort_order`,
  );
  const videosResult = await pool.query(
    `SELECT id, title, description, source_type, external_url, object_key, thumbnail_key, published_at
     FROM videos WHERE status = 'published' ORDER BY published_at DESC LIMIT 12`,
  );
  const settingsResult = await pool.query(
    `SELECT setting_key, setting_value FROM site_settings
     WHERE setting_key IN ('site_name', 'contact_email', 'facebook_url', 'youtube_url', 'instagram_url', 'maintenance_mode', 'header_text', 'footer_text')`,
  );

  const articles = articlesResult.rows.map((article) => ({
    ...article,
    image: mediaUrl(article.image_key),
  }));
  const sections = sectionsResult.rows.map((section) => ({
    ...section,
    articles: section.articles.map((article) => ({
      ...article,
      image: mediaUrl(article.imageKey),
    })),
  }));
  return res.json({
    categories: categoriesResult.rows,
    articles,
    sections,
    videos: videosResult.rows.map((video) => {
      const videoId = video.external_url ? youtubeVideoId(video.external_url) : null;
      return {
        ...video,
        videoUrl: video.object_key ? mediaUrl(video.object_key) : video.external_url,
        youtubeVideoId: videoId,
        thumbnailUrl: videoId
          ? `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`
          : mediaUrl(video.thumbnail_key),
      };
    }),
    settings: Object.fromEntries(settingsResult.rows.map((row) => [row.setting_key, row.setting_value])),
  });

});

api.get("/public/articles/:slug", async (req, res) => {
  const result = await pool.query(
    `SELECT a.id, a.slug, a.title, a.headline, a.summary, a.body, a.image_key,
            a.image_alt, a.attribution, a.image_caption, a.image_credit, a.published_at, u.username AS author,
            c.name AS category, c.slug AS category_slug
     FROM articles a JOIN users u ON u.id = a.author_id
     LEFT JOIN categories c ON c.id = a.category_id
     LEFT JOIN categories parent ON parent.id = c.parent_id
     WHERE a.slug = $1 AND a.status = 'published'
       AND c.slug IS DISTINCT FROM 'video-podcast'
       AND (c.id IS NULL OR (c.is_enabled = true AND (c.parent_id IS NULL OR parent.is_enabled = true)))`,
    [req.params.slug],
  );
  const article = result.rows[0];
  if (!article) return res.status(404).json({ error: "Article not found." });
  article.image = mediaUrl(article.image_key);
  return res.json({ article });
});

api.get("/admin/dashboard", requireAuth, async (req, res) => {
  const own = req.user.role === "moderator";
  const articleFilter = own ? "WHERE author_id = $1" : "";
  const videoFilter = own ? "WHERE author_id = $1" : "";
  const parameters = own ? [req.user.id] : [];
  const [articles, videos, categories, users, activity, recentPublished, recentUpdated] =
    await Promise.all([
      pool.query(
        `SELECT count(*) FILTER (WHERE status = 'published')::int AS published,
                count(*) FILTER (WHERE status = 'draft')::int AS drafts,
                count(*) FILTER (WHERE status = 'unpublished')::int AS unpublished
         FROM articles ${articleFilter}`,
        parameters,
      ),
      pool.query(`SELECT count(*)::int AS total FROM videos ${videoFilter}`, parameters),
      pool.query(
        `SELECT count(*) FILTER (WHERE parent_id IS NULL)::int AS categories,
                count(*) FILTER (WHERE parent_id IS NOT NULL)::int AS subcategories
         FROM categories`,
      ),
      own
        ? Promise.resolve({ rows: [{ total: null }] })
        : pool.query("SELECT count(*)::int AS total FROM users"),
      pool.query(
        `SELECT l.id, l.action, l.entity_type, l.entity_id, l.details, l.created_at, u.username
         FROM activity_log l LEFT JOIN users u ON u.id = l.actor_id
         ${own ? "WHERE l.actor_id = $1" : ""}
         ORDER BY l.created_at DESC LIMIT 8`,
        parameters,
      ),
      pool.query(
        `SELECT id, title, slug, published_at, updated_at FROM articles
         WHERE status = 'published' ${own ? "AND author_id = $1" : ""}
         ORDER BY published_at DESC LIMIT 5`,
        parameters,
      ),
      pool.query(
        `SELECT id, title, slug, status, updated_at FROM articles
         ${own ? "WHERE author_id = $1" : ""}
         ORDER BY updated_at DESC LIMIT 5`,
        parameters,
      ),
    ]);

  return res.json({
    stats: {
      ...articles.rows[0],
      videos: videos.rows[0].total,
      categories: categories.rows[0].categories,
      subcategories: categories.rows[0].subcategories,
      users: users.rows[0].total,
    },
    activity: activity.rows,
    recentlyPublished: recentPublished.rows,
    recentlyUpdated: recentUpdated.rows,
  });
});

api.get("/editor/categories", requireAuth, async (_req, res) => {
  const result = await pool.query(
    `SELECT c.id, c.name, c.slug, c.parent_id, parent.name AS parent_name
     FROM categories c LEFT JOIN categories parent ON parent.id = c.parent_id
     WHERE c.is_enabled = true AND (c.parent_id IS NULL OR parent.is_enabled = true)
     ORDER BY c.nav_sort_order, c.id`,
  );
  return res.json({ categories: result.rows });
});

api.get("/admin/articles", requireRoles(...EDITORS), async (req, res) => {
  const querySchema = z.object({
    q: text(150).optional(),
    status: z.enum(["draft", "published", "unpublished"]).optional(),
    categoryId: uuid.optional(),
    limit: z.coerce.number().int().min(1).max(100).default(50),
    offset: z.coerce.number().int().min(0).default(0),
  });
  const filters = parse(querySchema, req.query, res);
  if (!filters) return;
  const values = [];
  const where = [];
  const add = (value) => {
    values.push(value);
    return `$${values.length}`;
  };
  if (filters.q) {
    const param = add(`%${filters.q.replace(/[\\%_]/g, "\\$&")}%`);
    where.push(`(a.title ILIKE ${param} ESCAPE '\\' OR a.headline ILIKE ${param} ESCAPE '\\')`);
  }
  if (filters.status) where.push(`a.status = ${add(filters.status)}`);
  if (filters.categoryId) {
    const categoryParam = add(filters.categoryId);
    where.push(
      `(a.category_id = ${categoryParam} OR a.category_id IN (SELECT id FROM categories WHERE parent_id = ${categoryParam}))`,
    );
  }
  if (req.user.role === "moderator") where.push(`a.author_id = ${add(req.user.id)}`);
  const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";
  const limitParam = add(filters.limit);
  const offsetParam = add(filters.offset);
  const result = await pool.query(
    `SELECT a.id, a.slug, a.title, a.headline, a.summary, a.image_key, a.status,
            a.author_id, a.published_at, a.created_at, a.updated_at,
           u.username AS author, CASE WHEN p.id IS NULL THEN c.name ELSE p.name || ' / ' || c.name END AS category,
           c.id AS category_id, c.slug AS category_slug,
           COALESCE(string_agg(DISTINCT s.title, ', '), '') AS sections
     FROM articles a JOIN users u ON u.id = a.author_id
     LEFT JOIN categories c ON c.id = a.category_id
     LEFT JOIN categories p ON p.id = c.parent_id
     LEFT JOIN section_articles sa ON sa.article_id = a.id
     LEFT JOIN site_sections s ON s.id = sa.section_id
     ${whereSql}
     GROUP BY a.id, u.username, c.name, c.id, c.slug, p.id, p.name
     ORDER BY a.updated_at DESC LIMIT ${limitParam} OFFSET ${offsetParam}`,
    values,
  );
  const countValues = values.slice(0, where.length);
  const countResult = await pool.query(
    `SELECT count(*)::int AS total FROM articles a ${whereSql}`,
    countValues,
  );
  return res.json({
    articles: result.rows.map((article) => ({ ...article, image_url: mediaUrl(article.image_key) })),
    total: countResult.rows[0].total,
    limit: filters.limit,
    offset: filters.offset,
  });
});

const articleInput = z.object({
  title: text(240).min(1),
  headline: text(300).optional(),
  summary: text(1000).optional(),
  body: text(100000).optional(),
  imageKey: text(500).nullable().optional(),
  imageAlt: text(300).optional(),
  attribution: text(300).optional(),
  imageCaption: text(500).optional(),
  imageCredit: text(300).optional(),
  categoryId: uuid.nullable().optional(),
});

api.post("/admin/articles", requireRoles(...EDITORS), async (req, res) => {
  const input = parse(articleInput, req.body, res);
  if (!input) return;
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await assertCategory(client, input.categoryId);
    await assertMedia(client, input.imageKey, "image", req.user);
    const slug = await uniqueArticleSlug(client, input.title);
    const created = await client.query(
      `INSERT INTO articles
       (slug, title, headline, summary, body, image_key, image_alt, attribution, image_caption, image_credit, category_id, author_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) RETURNING id`,
      [
        slug,
        input.title,
        input.headline ?? "",
        input.summary ?? "",
        input.body ?? "",
        input.imageKey ?? null,
        input.imageAlt ?? "",
        input.attribution ?? "",
        input.imageCaption ?? "",
        input.imageCredit ?? "",
        input.categoryId ?? null,
        req.user.id,
      ],
    );
    await recordActivity(client, req.user.id, "created", "article", created.rows[0].id);
    await client.query("COMMIT");
    return res.status(201).json({ article: await articleRecord(pool, created.rows[0].id) });
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
});

api.get("/admin/articles/:id", requireRoles(...EDITORS), async (req, res) => {
  if (!uuid.safeParse(req.params.id).success) return res.status(400).json({ error: "Invalid article ID." });
  const result = await pool.query(
    `SELECT a.*, u.username AS author FROM articles a JOIN users u ON u.id = a.author_id WHERE a.id = $1`,
    [req.params.id],
  );
  const article = result.rows[0];
  if (!article) return res.status(404).json({ error: "Article not found." });
  if (req.user.role === "moderator" && article.author_id !== req.user.id) {
    return res.status(403).json({ error: "You can only view your own articles." });
  }
  article.image_url = mediaUrl(article.image_key);
  return res.json({ article });
});

api.patch("/admin/articles/:id", requireRoles(...EDITORS), async (req, res) => {
  const schema = articleInput.partial().extend({ slug: z.string().trim().min(1).max(160).regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/).optional() });
  const input = parse(schema, req.body, res);
  if (!input) return;
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const permission = await assertArticlePermission(client, req.params.id, req.user);
    if (permission.error) {
      await client.query("ROLLBACK");
      return res.status(permission.status).json({ error: permission.error });
    }
    if (input.categoryId !== undefined) {
      await assertCategory(
        client,
        input.categoryId,
        input.categoryId === permission.article.category_id,
      );
    }
    if (input.imageKey !== undefined) await assertMedia(client, input.imageKey, "image", req.user);
    const fields = {
      title: "title",
      headline: "headline",
      summary: "summary",
      body: "body",
      imageKey: "image_key",
      imageAlt: "image_alt",
      attribution: "attribution",
      imageCaption: "image_caption",
      imageCredit: "image_credit",
      categoryId: "category_id",
      slug: "slug",
    };
    const updates = Object.entries(fields).filter(([key]) => input[key] !== undefined);
    if (!updates.length) {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "No article changes were provided." });
    }
    const values = updates.map(([key]) => input[key]);
    values.push(req.params.id);
    await client.query(
      `UPDATE articles SET ${updates.map(([, column], index) => `${column} = $${index + 1}`).join(", ")},
       updated_at = now() WHERE id = $${values.length}`,
      values,
    );
    await recordActivity(client, req.user.id, "updated", "article", req.params.id);
    await client.query("COMMIT");
    return res.json({ article: await articleRecord(pool, req.params.id) });
  } catch (error) {
    await client.query("ROLLBACK");
    if (error.code === "23505") return res.status(409).json({ error: "That article URL is already in use." });
    throw error;
  } finally {
    client.release();
  }
});

api.patch("/admin/articles/:id/status", requireRoles(...MANAGERS), async (req, res) => {
  const input = parse(z.object({ status: z.enum(["draft", "published", "unpublished"]) }), req.body, res);
  if (!input) return;
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await client.query("SELECT id, status FROM articles WHERE id = $1 FOR UPDATE", [req.params.id]);
    if (!result.rowCount) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Article not found." });
    }
    const publishedAt = input.status === "published" ? new Date() : null;
    await client.query(
      `UPDATE articles SET status = $1,
       published_at = CASE WHEN $1 = 'published' THEN COALESCE(published_at, $2) ELSE NULL END,
       updated_at = now() WHERE id = $3`,
      [input.status, publishedAt, req.params.id],
    );
    await recordActivity(client, req.user.id, input.status, "article", req.params.id);
    await client.query("COMMIT");
    return res.json({ article: await articleRecord(pool, req.params.id) });
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
});

api.delete("/admin/articles/:id", requireRoles(...MANAGERS), async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await client.query("SELECT id FROM articles WHERE id = $1 FOR UPDATE", [req.params.id]);
    if (!result.rowCount) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Article not found." });
    }
    await recordActivity(client, req.user.id, "deleted", "article", req.params.id);
    await client.query("DELETE FROM articles WHERE id = $1", [req.params.id]);
    await client.query("COMMIT");
    return res.json({ ok: true });
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
});

api.get("/admin/categories", requireRoles(SUPER), async (_req, res) => {
  const result = await pool.query(
    `SELECT c.id, c.name, c.slug, c.parent_id, c.is_enabled, c.nav_sort_order,
            c.homepage_sort_order, c.homepage_layout, c.created_at, c.updated_at,
            p.name AS parent_name,
            count(a.id) FILTER (WHERE a.status = 'published' AND c.slug IS DISTINCT FROM 'video-podcast')::int AS published_articles,
            count(a.id)::int AS article_count
     FROM categories c LEFT JOIN categories p ON p.id = c.parent_id
     LEFT JOIN articles a ON a.category_id = c.id
     GROUP BY c.id, p.name ORDER BY c.nav_sort_order, c.id`,
  );
  return res.json({ categories: result.rows });
});

api.put("/admin/category-order", requireRoles(SUPER), async (req, res) => {
  const input = parse(
    z.object({
      navOrder: z.array(uuid).max(500),
      homepageOrder: z.array(uuid).max(500),
    }).strict(),
    req.body,
    res,
  );
  if (!input) return;
  if (
    new Set(input.navOrder).size !== input.navOrder.length
    || new Set(input.homepageOrder).size !== input.homepageOrder.length
  ) {
    return res.status(400).json({ error: "Category order lists cannot contain duplicates." });
  }

  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await client.query("SELECT id, parent_id FROM categories FOR UPDATE");
    const allIds = new Set(result.rows.map((category) => category.id));
    const topLevelIds = new Set(result.rows.filter((category) => !category.parent_id).map((category) => category.id));
    const matches = (ids, expected) => ids.length === expected.size && ids.every((id) => expected.has(id));
    if (!matches(input.navOrder, allIds) || !matches(input.homepageOrder, topLevelIds)) {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "Refresh the category lists and try saving the order again." });
    }

    for (const [index, id] of input.navOrder.entries()) {
      await client.query("UPDATE categories SET nav_sort_order = $1 WHERE id = $2", [index, id]);
    }
    for (const [index, id] of input.homepageOrder.entries()) {
      await client.query("UPDATE categories SET homepage_sort_order = $1 WHERE id = $2", [index, id]);
    }
    await recordActivity(client, req.user.id, "reordered", "categories", null);
    await client.query("COMMIT");
    return res.json({ ok: true });
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
});

const categoryInput = z.object({
  name: text(100).min(1),
  slug: z.string().trim().min(1).max(100).regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  parentId: uuid.nullable().optional(),
  homepageLayout: z.enum(["lead-headlines", "feature-headlines", "image-grid", "headline-list"]).optional(),
});

api.post("/admin/categories", requireRoles(SUPER), async (req, res) => {
  const input = parse(categoryInput, req.body, res);
  if (!input) return;
  if (input.parentId) {
    const parent = await pool.query("SELECT parent_id, is_enabled FROM categories WHERE id = $1", [input.parentId]);
    if (!parent.rowCount || parent.rows[0].parent_id || !parent.rows[0].is_enabled) {
      return res.status(400).json({ error: "Subcategories must be created under a top-level category." });
    }
  }
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await client.query(
      `INSERT INTO categories (name, slug, parent_id, homepage_layout)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [input.name, input.slug, input.parentId ?? null, input.homepageLayout ?? "lead-headlines"],
    );
    await recordActivity(client, req.user.id, "created", "category", result.rows[0].id);
    await client.query("COMMIT");
    return res.status(201).json({ category: result.rows[0] });
  } catch (error) {
    await client.query("ROLLBACK");
    if (error.code === "23505") return res.status(409).json({ error: "That category URL is already in use." });
    throw error;
  } finally {
    client.release();
  }
});

api.patch("/admin/categories/:id", requireRoles(SUPER), async (req, res) => {
  const schema = categoryInput.partial().extend({ isEnabled: z.boolean().optional() });
  const input = parse(schema, req.body, res);
  if (!input) return;
  if (input.parentId) {
    const parent = await pool.query("SELECT parent_id, is_enabled FROM categories WHERE id = $1", [input.parentId]);
    if (
      !parent.rowCount ||
      parent.rows[0].parent_id ||
      !parent.rows[0].is_enabled ||
      input.parentId === req.params.id
    ) {
      return res.status(400).json({ error: "Choose an eligible top-level parent category." });
    }
  }
  if (input.parentId) {
    const children = await pool.query("SELECT 1 FROM categories WHERE parent_id = $1 LIMIT 1", [req.params.id]);
    if (children.rowCount) {
      return res.status(409).json({ error: "Move this category's subcategories before making it a subcategory." });
    }
  }
  const fields = {
    name: "name",
    slug: "slug",
    parentId: "parent_id",
    isEnabled: "is_enabled",
    homepageLayout: "homepage_layout",
  };
  const updates = Object.entries(fields).filter(([key]) => input[key] !== undefined);
  if (!updates.length) return res.status(400).json({ error: "No category changes were provided." });
  const values = updates.map(([key]) => input[key]);
  values.push(req.params.id);
  try {
    const result = await pool.query(
      `UPDATE categories SET ${updates.map(([, column], i) => `${column} = $${i + 1}`).join(", ")},
       updated_at = now() WHERE id = $${values.length} RETURNING *`,
      values,
    );
    if (!result.rowCount) return res.status(404).json({ error: "Category not found." });
    await pool.query(
      `INSERT INTO activity_log (actor_id, action, entity_type, entity_id)
       VALUES ($1, 'updated', 'category', $2)`,
      [req.user.id, req.params.id],
    );
    return res.json({ category: result.rows[0] });
  } catch (error) {
    if (error.code === "23505") return res.status(409).json({ error: "That category URL is already in use." });
    if (error.code === "23503") return res.status(409).json({ error: "This category is used by content and cannot be moved." });
    throw error;
  }
});

api.delete("/admin/categories/:id", requireRoles(SUPER), async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const category = await client.query("SELECT id FROM categories WHERE id = $1 FOR UPDATE", [req.params.id]);
    if (!category.rowCount) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Category not found." });
    }
    const usage = await client.query(
      `SELECT count(a.id) FILTER (WHERE a.status = 'published')::int AS published,
              count(a.id)::int AS total
       FROM articles a
       WHERE a.category_id = $1`,
      [req.params.id],
    );
    if (usage.rows[0].total) {
      await client.query("ROLLBACK");
      return res.status(409).json({
        error: "Reassign or remove articles before deleting this category.",
        publishedArticles: usage.rows[0].published,
        totalArticles: usage.rows[0].total,
      });
    }
    await client.query("DELETE FROM categories WHERE id = $1", [req.params.id]);
    await recordActivity(client, req.user.id, "deleted", "category", req.params.id);
    await client.query("COMMIT");
    return res.json({ ok: true });
  } catch (error) {
    await client.query("ROLLBACK");
    if (error.code === "23503") return res.status(409).json({ error: "This category has subcategories; move or delete them first." });
    throw error;
  } finally {
    client.release();
  }
});

api.get("/admin/sections", requireRoles(SUPER), async (_req, res) => {
  const result = await pool.query(
    `SELECT s.id, s.slug, s.title, s.description, s.is_enabled, s.sort_order,
            COALESCE(json_agg(json_build_object(
              'id', a.id, 'title', a.title, 'status', a.status, 'image_key', a.image_key
            ) ORDER BY sa.sort_order) FILTER (WHERE a.id IS NOT NULL AND a.status = 'published'), '[]'::json) AS articles
     FROM site_sections s LEFT JOIN section_articles sa ON sa.section_id = s.id
     LEFT JOIN articles a ON a.id = sa.article_id
     GROUP BY s.id ORDER BY s.sort_order`,
  );
  return res.json({ sections: result.rows });
});

api.get("/admin/settings", requireRoles(SUPER), async (_req, res) => {
  const result = await pool.query(
    `SELECT setting_key, setting_value FROM site_settings
     WHERE setting_key IN ('site_name', 'contact_email', 'facebook_url', 'youtube_url', 'instagram_url')
     ORDER BY setting_key`,
  );
  return res.json({ settings: Object.fromEntries(result.rows.map((row) => [row.setting_key, row.setting_value])) });
});

api.patch("/admin/settings", requireRoles(SUPER), async (req, res) => {
  const input = parse(
    z.object({
      site_name: text(100).min(1).optional(),
      contact_email: z.string().email().max(254).optional(),
      facebook_url: z.union([z.literal(""), z.string().url().max(500).refine((value) => value.startsWith("https://"))]).optional(),
      youtube_url: z.union([z.literal(""), z.string().url().max(500).refine((value) => value.startsWith("https://"))]).optional(),
      instagram_url: z.union([z.literal(""), z.string().url().max(500).refine((value) => value.startsWith("https://"))]).optional(),
      maintenance_mode: z.enum(["true", "false"]).optional(),
      header_text: text(240).optional(),
      footer_text: text(500).optional(),
    }).strict(),
    req.body,
    res,
  );
  if (!input) return;
  const entries = Object.entries(input);
  if (!entries.length) return res.status(400).json({ error: "No settings were provided." });
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    for (const [key, value] of entries) {
      await client.query(
        `INSERT INTO site_settings (setting_key, setting_value)
         VALUES ($1, $2) ON CONFLICT (setting_key)
         DO UPDATE SET setting_value = EXCLUDED.setting_value, updated_at = now()`,
        [key, value],
      );
    }
    await recordActivity(client, req.user.id, "updated", "site_settings", null, { keys: entries.map(([key]) => key) });
    await client.query("COMMIT");
    return res.json({ ok: true });
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
});

api.patch("/admin/sections/:id", requireRoles(SUPER), async (req, res) => {
  const input = parse(
    z.object({
      title: text(120).optional(),
      description: text(500).optional(),
      isEnabled: z.boolean().optional(),
      sortOrder: z.number().int().min(0).max(1000).optional(),
      articleIds: z.array(uuid).max(50).optional(),
    }),
    req.body,
    res,
  );
  if (!input) return;
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const section = await client.query("SELECT id FROM site_sections WHERE id = $1 FOR UPDATE", [req.params.id]);
    if (!section.rowCount) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Section not found." });
    }
    const fields = { title: "title", description: "description", isEnabled: "is_enabled", sortOrder: "sort_order" };
    const updates = Object.entries(fields).filter(([key]) => input[key] !== undefined);
    if (updates.length) {
      const values = updates.map(([key]) => input[key]);
      values.push(req.params.id);
      await client.query(
        `UPDATE site_sections SET ${updates.map(([, column], i) => `${column} = $${i + 1}`).join(", ")},
         updated_at = now() WHERE id = $${values.length}`,
        values,
      );
    }
    if (input.articleIds) {
      await client.query("DELETE FROM section_articles WHERE section_id = $1", [req.params.id]);
      for (const [index, articleId] of input.articleIds.entries()) {
        const article = await client.query(
          `SELECT a.id FROM articles a
           LEFT JOIN categories c ON c.id = a.category_id
           WHERE a.id = $1 AND a.status = 'published'
             AND c.slug IS DISTINCT FROM 'video-podcast'`,
          [articleId],
        );
        if (!article.rowCount) {
          await client.query("ROLLBACK");
          return res.status(400).json({ error: "Homepage sections can only include published news articles, not video-only category entries." });
        }
        await client.query(
          "INSERT INTO section_articles (section_id, article_id, sort_order) VALUES ($1, $2, $3)",
          [req.params.id, articleId, index],
        );
      }
    }
    await recordActivity(client, req.user.id, "updated", "section", req.params.id);
    await client.query("COMMIT");
    return res.json({ ok: true });
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
});

api.get("/admin/videos", requireRoles(...EDITORS), async (req, res) => {
  const params = req.user.role === "moderator" ? [req.user.id] : [];
  const result = await pool.query(
    `SELECT v.*, u.username AS author FROM videos v JOIN users u ON u.id = v.author_id
     ${req.user.role === "moderator" ? "WHERE v.author_id = $1" : ""}
     ORDER BY v.updated_at DESC`,
    params,
  );
  return res.json({
    videos: result.rows.map((video) => {
      const videoId = video.external_url ? youtubeVideoId(video.external_url) : null;
      return {
        ...video,
        video_url: video.object_key ? mediaUrl(video.object_key) : video.external_url,
        youtube_video_id: videoId,
        thumbnail_url: videoId
          ? `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`
          : mediaUrl(video.thumbnail_key),
      };
    }),
  });
});

const videoInput = z.object({
  title: text(240).min(1),
  description: text(2000).optional(),
  externalUrl: z.string().url(),
});

function validateVideo(input, res) {
  if (!validYoutubeVideoUrl(input.externalUrl)) {
    return res.status(400).json({ error: "Use a valid HTTPS YouTube video link." });
  }
  return null;
}

api.post("/admin/videos", requireRoles(...EDITORS), async (req, res) => {
  const input = parse(videoInput, req.body, res);
  if (!input) return;
  const invalidVideo = validateVideo(input, res);
  if (invalidVideo) return invalidVideo;
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await client.query(
      `INSERT INTO videos (title, description, source_type, external_url, author_id)
       VALUES ($1, $2, 'external', $3, $4) RETURNING id`,
      [
        input.title,
        input.description ?? "",
        input.externalUrl,
        req.user.id,
      ],
    );
    await recordActivity(client, req.user.id, "created", "video", result.rows[0].id);
    await client.query("COMMIT");
    return res.status(201).json({ id: result.rows[0].id });
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
});

api.patch("/admin/videos/:id", requireRoles(...EDITORS), async (req, res) => {
  const input = parse(videoInput.partial(), req.body, res);
  if (!input) return;
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const permission = await assertVideoPermission(client, req.params.id, req.user);
    if (permission.error) {
      await client.query("ROLLBACK");
      return res.status(permission.status).json({ error: permission.error });
    }
    const current = permission.video;
    const merged = {
      title: input.title ?? "",
      description: input.description ?? "",
      externalUrl: input.externalUrl === undefined ? current.external_url : input.externalUrl,
    };
    if (input.externalUrl !== undefined && !validYoutubeVideoUrl(input.externalUrl)) {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "Use a valid HTTPS YouTube video link." });
    }
    const fields = {
      title: "title",
      description: "description",
      externalUrl: "external_url",
    };
    const updates = Object.entries(fields).filter(([key]) => input[key] !== undefined);
    if (!updates.length) {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "No video changes were provided." });
    }
    const values = updates.map(([key]) => merged[key]);
    values.push(req.params.id);
    await client.query(
      `UPDATE videos SET ${updates.map(([, column], i) => `${column} = $${i + 1}`).join(", ")},
       updated_at = now() WHERE id = $${values.length}`,
      values,
    );
    await recordActivity(client, req.user.id, "updated", "video", req.params.id);
    await client.query("COMMIT");
    return res.json({ ok: true });
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
});

api.patch("/admin/videos/:id/status", requireRoles(...MANAGERS), async (req, res) => {
  const input = parse(z.object({ status: z.enum(["draft", "published", "unpublished"]) }), req.body, res);
  if (!input) return;
  const result = await pool.query(
    `UPDATE videos SET status = $1,
     published_at = CASE WHEN $1 = 'published' THEN COALESCE(published_at, now()) ELSE NULL END,
     updated_at = now() WHERE id = $2 RETURNING id`,
    [input.status, req.params.id],
  );
  if (!result.rowCount) return res.status(404).json({ error: "Video not found." });
  await pool.query(
    "INSERT INTO activity_log (actor_id, action, entity_type, entity_id) VALUES ($1, $2, 'video', $3)",
    [req.user.id, input.status, req.params.id],
  );
  return res.json({ ok: true });
});

api.delete("/admin/videos/:id", requireRoles(...MANAGERS), async (req, res) => {
  const result = await pool.query("DELETE FROM videos WHERE id = $1 RETURNING id", [req.params.id]);
  if (!result.rowCount) return res.status(404).json({ error: "Video not found." });
  await pool.query(
    "INSERT INTO activity_log (actor_id, action, entity_type, entity_id) VALUES ($1, 'deleted', 'video', $2)",
    [req.user.id, req.params.id],
  );
  return res.json({ ok: true });
});

api.get("/admin/users", requireRoles(...MANAGERS), async (_req, res) => {
  const result = await pool.query(
    `SELECT u.id, u.username, u.email, u.role, u.status, u.created_at, u.last_login_at,
            (SELECT count(*)::int FROM admin_sessions s
             WHERE s.user_id = u.id AND s.expires_at > now()) AS active_sessions
     FROM users u ORDER BY u.created_at DESC`,
  );
  return res.json({ users: result.rows });
});

const createUserSchema = z.object({
  username: z.string().trim().min(3).max(48).regex(/^[a-zA-Z0-9._-]+$/),
  email: z.string().trim().email().max(254),
  password: z.string().min(12).max(72).refine((value) => Buffer.byteLength(value, "utf8") <= 72),
  role: z.enum(["super_admin", "admin", "moderator"]).optional(),
});

api.post("/admin/users", requireRoles(...MANAGERS), async (req, res) => {
  const input = parse(createUserSchema, req.body, res);
  if (!input) return;
  if (req.user.role !== SUPER && input.role && input.role !== "moderator") {
    return res.status(403).json({ error: "Admins can only create Moderator accounts." });
  }
  const role = req.user.role === SUPER ? input.role || "moderator" : "moderator";
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await client.query(
      `INSERT INTO users (username, email, password_hash, role)
       VALUES ($1, lower($2), $3, $4)
       RETURNING id, username, email, role, status, created_at`,
      [input.username, input.email, await bcrypt.hash(input.password, 12), role],
    );
    await recordActivity(client, req.user.id, "created", "user", result.rows[0].id, { role });
    await client.query("COMMIT");
    return res.status(201).json({ user: result.rows[0] });
  } catch (error) {
    await client.query("ROLLBACK");
    if (error.code === "23505") return res.status(409).json({ error: "That username or email is already in use." });
    throw error;
  } finally {
    client.release();
  }
});

api.patch("/admin/users/:id", requireRoles(SUPER), async (req, res) => {
  const input = parse(
    z.object({
      username: z.string().trim().min(3).max(48).regex(/^[a-zA-Z0-9._-]+$/).optional(),
      email: z.string().trim().email().max(254).optional(),
      role: z.enum(["super_admin", "admin", "moderator"]).optional(),
      status: z.enum(["active", "suspended"]).optional(),
    }),
    req.body,
    res,
  );
  if (!input) return;
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT pg_advisory_xact_lock(142857, 1)");
    const target = await client.query("SELECT id, role, status FROM users WHERE id = $1 FOR UPDATE", [req.params.id]);
    if (!target.rowCount) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "User not found." });
    }
    const current = target.rows[0];
    if (req.user.id === current.id && input.status === "suspended") {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "You cannot suspend your own account." });
    }
    const losesSuperAdmin =
      current.role === SUPER &&
      ((input.role && input.role !== SUPER) || input.status === "suspended");
    if (losesSuperAdmin) {
      const activeAdmins = await client.query(
        "SELECT count(*)::int AS total FROM users WHERE role = 'super_admin' AND status = 'active' AND id <> $1",
        [current.id],
      );
      if (!activeAdmins.rows[0].total) {
        await client.query("ROLLBACK");
        return res.status(409).json({ error: "At least one active Super Admin must remain." });
      }
    }
    const fields = { username: "username", email: "email", role: "role", status: "status" };
    const updates = Object.entries(fields).filter(([key]) => input[key] !== undefined);
    if (!updates.length) {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "No account changes were provided." });
    }
    const values = updates.map(([key]) => key === "email" ? input[key].toLowerCase() : input[key]);
    values.push(req.params.id);
    const updated = await client.query(
      `UPDATE users SET ${updates.map(([, column], i) => `${column} = $${i + 1}`).join(", ")},
       updated_at = now() WHERE id = $${values.length}
       RETURNING id, username, email, role, status, created_at, last_login_at`,
      values,
    );
    if (input.status === "suspended" || (input.role && input.role !== current.role)) {
      await client.query("DELETE FROM admin_sessions WHERE user_id = $1", [req.params.id]);
    }
    await recordActivity(client, req.user.id, "updated", "user", req.params.id, input);
    await client.query("COMMIT");
    return res.json({ user: updated.rows[0] });
  } catch (error) {
    await client.query("ROLLBACK");
    if (error.code === "23505") return res.status(409).json({ error: "That username or email is already in use." });
    throw error;
  } finally {
    client.release();
  }
});

api.post("/admin/users/:id/reset-password", requireRoles(SUPER), async (req, res) => {
  const input = parse(
    z.object({
      password: z.string().min(12).max(72).refine((value) => Buffer.byteLength(value, "utf8") <= 72),
    }),
    req.body,
    res,
  );
  if (!input) return;
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const updated = await client.query(
      "UPDATE users SET password_hash = $1, updated_at = now() WHERE id = $2 RETURNING id",
      [await bcrypt.hash(input.password, 12), req.params.id],
    );
    if (!updated.rowCount) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "User not found." });
    }
    await client.query("DELETE FROM admin_sessions WHERE user_id = $1", [req.params.id]);
    await recordActivity(client, req.user.id, "password_reset", "user", req.params.id);
    await client.query("COMMIT");
    return res.json({ ok: true });
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
});

api.get("/admin/users/:id/activity", requireRoles(...MANAGERS), async (req, res) => {
  const result = await pool.query(
    `SELECT id, action, entity_type, entity_id, details, created_at
     FROM activity_log WHERE actor_id = $1 ORDER BY created_at DESC LIMIT 50`,
    [req.params.id],
  );
  return res.json({ activity: result.rows });
});


// Editorial collections and newsroom content modules.
const contentModules = new Set(["writings", "ads"]);
api.get("/admin/content/:module", requireRoles(SUPER), async (req, res) => {
  const module = req.params.module;
  if (!contentModules.has(module)) return res.status(404).json({ error: "Content module not found." });
  const result = await pool.query(
    "SELECT * FROM admin_content_entries WHERE module = $1 ORDER BY sort_order, created_at DESC",
    [module],
  );
  return res.json({ entries: result.rows });
});
api.post("/admin/content/:module", requireRoles(SUPER), async (req, res) => {
  const module = req.params.module;
  if (!contentModules.has(module)) return res.status(404).json({ error: "Content module not found." });
  const input = parse(z.object({
    title: text(180).min(1), content: text(20000).optional(),
    targetUrl: text(1000).optional(), imageUrl: text(1000).optional(),
    placement: text(80).optional(), isEnabled: z.boolean().optional(),
    sortOrder: z.number().int().min(0).max(10000).optional(),
  }), req.body, res);
  if (!input) return;
  const result = await pool.query(
    `INSERT INTO admin_content_entries
     (module, title, content, target_url, image_url, placement, is_enabled, sort_order, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
    [module,input.title,input.content||"",input.targetUrl||"",input.imageUrl||"",input.placement||"",input.isEnabled??true,input.sortOrder??0,req.user.id],
  );
  await recordActivity(pool, req.user.id, "created", module, result.rows[0].id);
  return res.status(201).json({ entry: result.rows[0] });
});
api.patch("/admin/content/:module/:id", requireRoles(SUPER), async (req, res) => {
  const module = req.params.module;
  if (!contentModules.has(module)) return res.status(404).json({ error: "Content module not found." });
  const input = parse(z.object({
    title: text(180).min(1).optional(), content: text(20000).optional(),
    targetUrl: text(1000).optional(), imageUrl: text(1000).optional(),
    placement: text(80).optional(), isEnabled: z.boolean().optional(),
    sortOrder: z.number().int().min(0).max(10000).optional(),
  }).strict(), req.body, res);
  if (!input) return;
  const columns={title:"title",content:"content",targetUrl:"target_url",imageUrl:"image_url",placement:"placement",isEnabled:"is_enabled",sortOrder:"sort_order"};
  const updates=Object.entries(columns).filter(([key])=>input[key]!==undefined);
  if(!updates.length) return res.status(400).json({error:"No changes provided."});
  const values=updates.map(([key])=>input[key]); values.push(module,req.params.id);
  const result=await pool.query(
    `UPDATE admin_content_entries SET ${updates.map(([,col],i)=>col+" = $"+(i+1)).join(", ")}, updated_at=now()
     WHERE module = $${values.length-1} AND id = $${values.length} RETURNING *`,values);
  if(!result.rowCount) return res.status(404).json({error:"Entry not found."});
  await recordActivity(pool,req.user.id,"updated",module,req.params.id);
  return res.json({entry:result.rows[0]});
});
api.delete("/admin/content/:module/:id", requireRoles(SUPER), async (req,res)=>{
  if(!contentModules.has(req.params.module)) return res.status(404).json({error:"Content module not found."});
  const result=await pool.query("DELETE FROM admin_content_entries WHERE module=$1 AND id=$2 RETURNING id",[req.params.module,req.params.id]);
  if(!result.rowCount) return res.status(404).json({error:"Entry not found."});
  await recordActivity(pool,req.user.id,"deleted",req.params.module,req.params.id);
  return res.json({ok:true});
});

const placements = new Set(["recent","breaking","popular","special"]);
api.get("/admin/placements/:placement", requireRoles(SUPER), async (req,res)=>{
  if(!placements.has(req.params.placement)) return res.status(404).json({error:"Placement not found."});
  const result=await pool.query(
    `SELECT a.id,a.title,a.headline,a.slug,a.status,p.sort_order
     FROM article_placements p JOIN articles a ON a.id=p.article_id
     WHERE p.placement=$1 ORDER BY p.sort_order,a.published_at DESC`,[req.params.placement]);
  return res.json({articles:result.rows});
});
api.put("/admin/placements/:placement", requireRoles(SUPER), async (req,res)=>{
  const placement=req.params.placement;
  if(!placements.has(placement)) return res.status(404).json({error:"Placement not found."});
  const input=parse(z.object({articleIds:z.array(uuid).max(100)}),req.body,res);
  if(!input) return;
  const client=await pool.connect();
  try{
    await client.query("BEGIN");
    const valid=await client.query("SELECT id FROM articles WHERE id=ANY($1::uuid[]) AND status='published'",[input.articleIds]);
    if(valid.rowCount!==new Set(input.articleIds).size){
      await client.query("ROLLBACK"); return res.status(400).json({error:"Only published articles can be featured."});
    }
    await client.query("DELETE FROM article_placements WHERE placement=$1",[placement]);
    for(const [index,id] of input.articleIds.entries()){
      await client.query("INSERT INTO article_placements(article_id,placement,sort_order) VALUES($1,$2,$3)",[id,placement,index]);
    }
    await recordActivity(client,req.user.id,"updated","placement",placement);
    await client.query("COMMIT");
    return res.json({ok:true});
  }catch(error){await client.query("ROLLBACK");throw error;}finally{client.release();}
});

api.get("/admin/profile", requireAuth, async (req,res)=>{
  const result=await pool.query("SELECT id,username,email,role,avatar_url FROM users WHERE id=$1",[req.user.id]);
  return res.json({profile:result.rows[0]});
});
api.patch("/admin/profile", requireAuth, async (req,res)=>{
  const input=parse(z.object({
    username:z.string().trim().min(3).max(48).regex(/^[a-zA-Z0-9._-]+$/).optional(),
    email:z.string().trim().email().max(254).optional(),
    avatarUrl:z.union([z.literal(""),z.string().url().max(1000).refine(v=>v.startsWith("https://"))]).optional(),
    currentPassword:z.string().min(1).max(72).optional(),
    newPassword:z.string().min(12).max(72).refine(v=>Buffer.byteLength(v,"utf8")<=72).optional(),
  }).strict().refine(v=>(v.newPassword===undefined)===(v.currentPassword===undefined),{message:"Current and new password must be provided together."}),req.body,res);
  if(!input) return;
  const current=await pool.query("SELECT password_hash FROM users WHERE id=$1",[req.user.id]);
  if(input.newPassword && !(await bcrypt.compare(input.currentPassword,current.rows[0].password_hash))){
    return res.status(400).json({error:"Current password is incorrect."});
  }
  const updates=[],values=[];
  if(input.username!==undefined){values.push(input.username);updates.push("username=$"+values.length);}
  if(input.email!==undefined){values.push(input.email.toLowerCase());updates.push("email=$"+values.length);}
  if(input.avatarUrl!==undefined){values.push(input.avatarUrl);updates.push("avatar_url=$"+values.length);}
  if(input.newPassword){values.push(await bcrypt.hash(input.newPassword,12));updates.push("password_hash=$"+values.length);}
  if(!updates.length) return res.status(400).json({error:"No profile changes provided."});
  values.push(req.user.id);
  try{
    await pool.query(`UPDATE users SET ${updates.join(", ")},updated_at=now() WHERE id=$${values.length}`,values);
    if(input.newPassword) await pool.query("DELETE FROM admin_sessions WHERE user_id=$1 AND id <> $2",[req.user.id,req.session.id]);
    await recordActivity(pool,req.user.id,"updated","profile",req.user.id);
    return res.json({ok:true});
  }catch(error){if(error.code==="23505")return res.status(409).json({error:"Username or email already in use."});throw error;}
});
