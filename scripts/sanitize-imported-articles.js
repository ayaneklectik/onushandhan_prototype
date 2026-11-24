import { randomUUID } from "node:crypto";
import {
  CopyObjectCommand,
  DeleteObjectCommand,
  HeadObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import { config } from "../server/config.js";
import { pool } from "../server/db.js";

const media = config.media;
const bucket = media.bucket;
let s3;

function storage() {
  if (!bucket || !media.endpoint || !media.accessKeyId || !media.secretAccessKey) {
    throw new Error("R2 is not fully configured.");
  }
  s3 ||= new S3Client({
    region: media.region,
    endpoint: media.endpoint,
    forcePathStyle: media.forcePathStyle,
    credentials: { accessKeyId: media.accessKeyId, secretAccessKey: media.secretAccessKey },
  });
  return s3;
}

function slugify(value) {
  return String(value || "").normalize("NFKD").toLowerCase()
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 100);
}

function clean(value) {
  return String(value || "")
    .replace(/<a\b[^>]*href=["'][^"']*(?:24ghonta|24-ghonta)[^"']*["'][^>]*>([\s\S]*?)<\/a>/gi, "$1")
    .replace(/(?:সূত্র|সৌজন্যে|প্রকাশক|প্রকাশনা)\s*[:：-]?\s*(?:২৪\s*ঘণ্টা(?:\s*টিভি)?|২৪\s*ঘন্টা(?:\s*টিভি)?|24\s*ghonta(?:\s*tv)?|24ghontatv(?:\.com)?)/giu, "")
    .replace(/https?:\/\/(?:www\.)?24ghontatv\.com[^\s"'<>)]*/gi, "")
    .replace(/(?:24\s*ghonta\s*tv|24ghontatv|24-ghonta-tv|২৪\s*ঘণ্টা\s*টিভি|২৪\s*ঘন্টা\s*টিভি)/giu, "")
    .replace(/[ \t]{2,}/g, " ").replace(/\s+([,।;:])/g, "$1").trim();
}

function copySource(key) {
  return `/${bucket}/${key.split("/").map(encodeURIComponent).join("/")}`;
}

async function main() {
  const client = storage();
  const assetsResult = await pool.query(
    "SELECT id, object_key, media_type, content_type, size_bytes, status, uploader_id FROM media_assets WHERE object_key ILIKE '%24ghonta%' OR object_key ILIKE '%24-ghonta%' ORDER BY object_key",
  );
  const trackedResult = await pool.query(
    "SELECT e.article_id, a.slug, a.title, a.image_key FROM external_article_imports e JOIN articles a ON a.id=e.article_id ORDER BY a.created_at",
  );
  const trackedIds = new Set(trackedResult.rows.map((row) => row.article_id));
  const allArticleRows = await pool.query(
    "SELECT id, slug, title, headline, summary, body, image_alt, image_caption, image_credit, attribution, image_key FROM articles ORDER BY created_at",
  );
  const targetArticles = allArticleRows.rows.filter((row) =>
    trackedIds.has(row.id) || /24ghonta|24-ghonta/i.test(row.slug || "") ||
    [row.title, row.headline, row.summary, row.body, row.image_alt, row.image_caption, row.image_credit, row.attribution]
      .some((value) => /24\s*ghonta|24ghonta|২৪\s*ঘণ্টা\s*টিভি|২৪\s*ঘন্টা\s*টিভি/i.test(String(value || "")))
  );
  const replacements = [];
  for (const asset of assetsResult.rows) {
    const extension = asset.object_key.match(/\.[a-z0-9]{2,5}$/i)?.[0] || "";
    const newKey = `media/news/${randomUUID()}${extension}`;
    await client.send(new HeadObjectCommand({ Bucket: bucket, Key: asset.object_key }));
    await client.send(new CopyObjectCommand({
      Bucket: bucket, Key: newKey, CopySource: copySource(asset.object_key), MetadataDirective: "COPY",
    }));
    replacements.push({ ...asset, newKey });
  }

  const db = await pool.connect();
  try {
    await db.query("BEGIN");
    for (const asset of replacements) {
      const newAssetId = randomUUID();
      await db.query(
        `INSERT INTO media_assets (id, object_key, media_type, content_type, size_bytes, status, uploader_id)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [newAssetId, asset.newKey, asset.media_type, asset.content_type, asset.size_bytes, asset.status, asset.uploader_id],
      );
      await db.query("UPDATE articles SET image_key=$1 WHERE image_key=$2", [asset.newKey, asset.object_key]);
      await db.query("UPDATE videos SET object_key=$1 WHERE object_key=$2", [asset.newKey, asset.object_key]);
      await db.query("UPDATE videos SET thumbnail_key=$1 WHERE thumbnail_key=$2", [asset.newKey, asset.object_key]);
      await db.query("DELETE FROM media_assets WHERE id=$1", [asset.id]);
    }

    for (const article of targetArticles) {
      const oldNumericId = article.slug?.match(/(\d+)$/)?.[1];
      const base = slugify(article.title) || `news-${oldNumericId || article.id.slice(0, 8)}`;
      let slug = base;
      let suffix = 2;
      while ((await db.query("SELECT 1 FROM articles WHERE slug=$1 AND id<>$2", [slug, article.id])).rowCount) {
        slug = `${base}-${suffix++}`;
      }
      await db.query(
        `UPDATE articles
         SET slug=$1, title=$2, headline=$3, summary=$4, body=$5, image_alt=$6,
             image_caption=$7, image_credit=$8, attribution=''
         WHERE id=$9`,
        [
          slug, clean(article.title), clean(article.headline), clean(article.summary),
          clean(article.body), clean(article.image_alt), clean(article.image_caption),
          clean(article.image_credit), article.id,
        ],
      );
      console.log(`Sanitized article ${article.id}: ${article.slug} -> ${slug}`);
    }

    await db.query("DROP TABLE IF EXISTS external_article_imports");
    await db.query("COMMIT");
  } catch (error) {
    await db.query("ROLLBACK");
    for (const asset of replacements) {
      try { await client.send(new DeleteObjectCommand({ Bucket: bucket, Key: asset.newKey })); } catch {}
    }
    throw error;
  } finally {
    db.release();
  }

  for (const asset of replacements) {
    await client.send(new DeleteObjectCommand({ Bucket: bucket, Key: asset.object_key }));
  }
  console.log(`Complete. Sanitized ${targetArticles.length} articles, renamed ${replacements.length} media objects, removed import tracking. Old article slugs now return 404.`);
}

main().catch((error) => {
  console.error("Sanitization failed:", error);
  process.exitCode = 1;
}).finally(() => pool.end());
