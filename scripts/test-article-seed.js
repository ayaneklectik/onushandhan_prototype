import { readFile, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  DeleteObjectCommand,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import { config } from "../server/config.js";
import { pool } from "../server/db.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const assetDirectory = path.join(root, "test-assets");
const assetPrefix = "test-seed/onushandhan";
const assetCount = 8;
const topics = [
  "নথি যাচাইয়ের প্রক্রিয়া",
  "সিদ্ধান্ত গ্রহণের সময়রেখা",
  "জনস্বার্থে তথ্যের গুরুত্ব",
  "জবাবদিহি নিশ্চিত করার উপায়",
  "স্থানীয় পর্যায়ে প্রভাবের চিত্র",
  "তথ্য যাচাইয়ের ধাপ",
  "প্রশাসনিক প্রক্রিয়া বোঝার পাঠ",
  "নাগরিক পর্যবেক্ষণের ভূমিকা",
  "প্রতিবেদন তৈরির পদ্ধতি",
  "স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন",
];

let client;

function storage() {
  const media = config.media;
  if (!media.bucket || !media.endpoint || !media.accessKeyId || !media.secretAccessKey || !media.publicBaseUrl) {
    throw new Error("R2 is not fully configured. Check MEDIA_BUCKET, MEDIA_ENDPOINT, MEDIA_ACCESS_KEY_ID, MEDIA_SECRET_ACCESS_KEY and MEDIA_PUBLIC_BASE_URL.");
  }
  client ||= new S3Client({
    region: media.region,
    endpoint: media.endpoint,
    forcePathStyle: media.forcePathStyle,
    credentials: {
      accessKeyId: media.accessKeyId,
      secretAccessKey: media.secretAccessKey,
    },
  });
  return client;
}

function assetKey(index) {
  return `${assetPrefix}/article-${index}.svg`;
}

async function ensureAssets(uploaderId) {
  const s3 = storage();
  const keys = [];
  for (let index = 1; index <= assetCount; index += 1) {
    const filename = `article-${index}.svg`;
    const localPath = path.join(assetDirectory, filename);
    const body = await readFile(localPath);
    const fileStats = await stat(localPath);
    const key = assetKey(index);
    const existing = await pool.query(
      "SELECT id, uploader_id, content_type FROM media_assets WHERE object_key = $1",
      [key],
    );
    if (existing.rowCount && (existing.rows[0].uploader_id !== uploaderId || existing.rows[0].content_type !== "image/svg+xml")) {
      throw new Error(`Reserved demo media key is already used by another asset: ${key}`);
    }

    await s3.send(new PutObjectCommand({
      Bucket: config.media.bucket,
      Key: key,
      Body: body,
      ContentType: "image/svg+xml",
      CacheControl: "public, max-age=3600",
    }));

    if (!existing.rowCount) {
      await pool.query(
        `INSERT INTO media_assets (object_key, media_type, content_type, size_bytes, status, uploader_id)
         VALUES ($1, 'image', 'image/svg+xml', $2, 'ready', $3)`,
        [key, fileStats.size, uploaderId],
      );
    } else {
      await pool.query(
        "UPDATE media_assets SET size_bytes = $1, status = 'ready' WHERE object_key = $2",
        [fileStats.size, key],
      );
    }
    keys.push(key);
  }
  return keys;
}

function articleCopy(categoryName, topic, number) {
  const title = `ডেমো: ${categoryName} — ${topic}`;
  return {
    title,
    headline: `নমুনা ${number}: ${categoryName} বিষয়ে পরীক্ষামূলক প্রতিবেদন`,
    summary: `এটি ${categoryName} বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।`,
    body: [
      `<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “${categoryName}” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>`,
      `<p>এই নমুনা প্রতিবেদনের বিষয়: ${topic}। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>`,
      "<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>",
    ].join("\n\n"),
  };
}

export async function seedTestArticles() {
  const seeded = await pool.query("SELECT count(*)::int AS total FROM test_seeded_articles");
  if (seeded.rows[0].total > 0) {
    console.log(`Test articles already exist (${seeded.rows[0].total}). Run npm run seed:remove-test-articles before creating a fresh set.`);
    return;
  }

  const [authorResult, categoryResult] = await Promise.all([
    pool.query(
      `SELECT id FROM users WHERE status = 'active'
       ORDER BY CASE role WHEN 'super_admin' THEN 1 WHEN 'admin' THEN 2 ELSE 3 END, created_at
       LIMIT 1`,
    ),
    pool.query(
      `SELECT c.id, c.name, c.slug
       FROM categories c
       LEFT JOIN categories parent ON parent.id = c.parent_id
       WHERE c.is_enabled = true
         AND c.slug <> 'video-podcast'
         AND (c.parent_id IS NULL OR parent.is_enabled = true)
       ORDER BY c.nav_sort_order NULLS LAST, c.name`,
    ),
  ]);
  if (!authorResult.rowCount) throw new Error("No active admin account exists. Create the first administrator before seeding.");
  if (!categoryResult.rowCount) throw new Error("No enabled article categories were found.");

  const imageKeys = await ensureAssets(authorResult.rows[0].id);
  const db = await pool.connect();
  let created = 0;
  try {
    await db.query("BEGIN");
    for (let categoryIndex = 0; categoryIndex < categoryResult.rows.length; categoryIndex += 1) {
      const category = categoryResult.rows[categoryIndex];
      for (let index = 0; index < 10; index += 1) {
        const number = index + 1;
        const seedKey = `${category.slug}:${number}`;
        const slug = `demo-${category.slug}-${String(number).padStart(2, "0")}`;
        const copy = articleCopy(category.name, topics[index], number);
        const inserted = await db.query(
          `INSERT INTO articles
             (slug, title, headline, summary, body, image_key, image_alt, category_id,
              status, author_id, published_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'published', $9,
                   now() - ($10::int * interval '1 hour'))
           RETURNING id`,
          [
            slug,
            copy.title,
            copy.headline,
            copy.summary,
            copy.body,
            imageKeys[(index + categoryIndex) % imageKeys.length],
            `পরীক্ষামূলক ছবি ${((index + categoryIndex) % imageKeys.length) + 1}`,
            category.id,
            authorResult.rows[0].id,
            categoryIndex * 10 + index,
          ],
        );
        await db.query(
          "INSERT INTO test_seeded_articles (article_id, seed_key) VALUES ($1, $2)",
          [inserted.rows[0].id, seedKey],
        );
        created += 1;
      }
    }
    await db.query("COMMIT");
  } catch (error) {
    await db.query("ROLLBACK");
    throw error;
  } finally {
    db.release();
  }
  console.log(`Created ${created} clearly labelled demo articles across ${categoryResult.rowCount} categories, with ${imageKeys.length} R2 images.`);
}

export async function removeTestArticles() {
  const db = await pool.connect();
  let deletedArticles = 0;
  try {
    await db.query("BEGIN");
    const deleted = await db.query(
      `DELETE FROM articles
       WHERE id IN (SELECT article_id FROM test_seeded_articles)
       RETURNING id`,
    );
    deletedArticles = deleted.rowCount;
    await db.query("COMMIT");
  } catch (error) {
    await db.query("ROLLBACK");
    throw error;
  } finally {
    db.release();
  }

  const assets = await pool.query(
    "SELECT id, object_key FROM media_assets WHERE object_key LIKE $1 ORDER BY object_key",
    [`${assetPrefix}/%`],
  );
  let deletedAssets = 0;
  let preservedAssets = 0;
  for (const asset of assets.rows) {
    const references = await pool.query(
      `SELECT
         EXISTS (SELECT 1 FROM articles WHERE image_key = $1) AS article_ref,
         EXISTS (SELECT 1 FROM videos WHERE object_key = $1 OR thumbnail_key = $1) AS video_ref`,
      [asset.object_key],
    );
    if (references.rows[0].article_ref || references.rows[0].video_ref) {
      preservedAssets += 1;
      continue;
    }
    await storage().send(new DeleteObjectCommand({
      Bucket: config.media.bucket,
      Key: asset.object_key,
    }));
    await pool.query("DELETE FROM media_assets WHERE id = $1", [asset.id]);
    deletedAssets += 1;
  }
  console.log(`Removed ${deletedArticles} demo articles and ${deletedAssets} unused R2 images. Preserved ${preservedAssets} image(s) still referenced by other content.`);
}
