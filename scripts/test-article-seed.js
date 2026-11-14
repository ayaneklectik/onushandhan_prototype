import { readFile, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  DeleteObjectCommand, PutObjectCommand, S3Client,
} from "@aws-sdk/client-s3";
import { config } from "../server/config.js";
import { pool } from "../server/db.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const assetPrefix = "test-seed/onushandhan/v1";
const assetCount = 8;
const topics = [
  "নথি যাচাইয়ের প্রক্রিয়া", "সিদ্ধান্ত গ্রহণের সময়রেখা", "জনস্বার্থে তথ্যের গুরুত্ব",
  "জবাবদিহি নিশ্চিত করার উপায়", "স্থানীয় পর্যায়ে প্রভাবের চিত্র", "তথ্য যাচাইয়ের ধাপ",
  "প্রশাসনিক প্রক্রিয়া বোঝার পাঠ", "নাগরিক পর্যবেক্ষণের ভূমিকা",
  "প্রতিবেদন তৈরির পদ্ধতি", "স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন",
];
let s3;
function storage() {
  if (!config.media.bucket || !config.media.endpoint || !config.media.accessKeyId || !config.media.secretAccessKey || !config.media.publicBaseUrl) {
    throw new Error("R2 is not fully configured. Check MEDIA_BUCKET, MEDIA_ENDPOINT, MEDIA_ACCESS_KEY_ID, MEDIA_SECRET_ACCESS_KEY and MEDIA_PUBLIC_BASE_URL.");
  }
  s3 ||= new S3Client({
    region: config.media.region, endpoint: config.media.endpoint,
    forcePathStyle: config.media.forcePathStyle,
    credentials: { accessKeyId: config.media.accessKeyId, secretAccessKey: config.media.secretAccessKey },
  });
  return s3;
}

async function ensureAssets(db, uploaderId) {
  const keys = [];
  for (let index = 1; index <= assetCount; index += 1) {
    const filename = `article-${index}.svg`;
    const localPath = path.join(root, "test-assets", filename);
    const body = await readFile(localPath);
    const fileStats = await stat(localPath);
    const key = `${assetPrefix}/${filename}`;
    const found = await db.query(
      "SELECT tsa.media_asset_id FROM test_seed_assets tsa WHERE tsa.object_key = $1",
      [key],
    );
    if (found.rowCount) { keys.push(key); continue; }
    await storage().send(new PutObjectCommand({
      Bucket: config.media.bucket, Key: key, Body: body,
      ContentType: "image/svg+xml", CacheControl: "public, max-age=3600",
    }));
    const asset = await db.query(
      "INSERT INTO media_assets (object_key, media_type, content_type, size_bytes, status, uploader_id) VALUES ($1, 'image', 'image/svg+xml', $2, 'ready', $3) RETURNING id",
      [key, fileStats.size, uploaderId],
    );
    await db.query(
      "INSERT INTO test_seed_assets (object_key, media_asset_id) VALUES ($1, $2)",
      [key, asset.rows[0].id],
    );
    keys.push(key);
  }
  return keys;
}

function articleCopy(categoryName, topic, number) {
  return {
    title: `ডেমো: ${categoryName} — ${topic} (${String(number).padStart(2, "0")})`,
    headline: `নমুনা ${number}: ${categoryName} বিষয়ে পরীক্ষামূলক প্রতিবেদন`,
    summary: `এটি ${categoryName} বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।`,
    body: [
      `<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “${categoryName}” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>`,
      `<p>এই নমুনা প্রতিবেদনের বিষয়: ${topic}। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>`,
      "<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>",
    ].join("\\n\\n"),
  };
}

export async function seedTestArticles() {
  const existing = await pool.query("SELECT count(*)::int AS total FROM test_seed_articles");
  if (existing.rows[0].total > 0) {
    console.log(`Test articles already exist (${existing.rows[0].total}). Remove them before creating a fresh set.`);
    return;
  }
  const [authorResult, categoryResult] = await Promise.all([
    pool.query(`SELECT id FROM users WHERE status = 'active'
      AND role IN ('super_admin','admin')
      ORDER BY CASE role WHEN 'super_admin' THEN 1 ELSE 2 END, created_at LIMIT 1`),
    pool.query(`SELECT c.id, c.name, c.slug FROM categories c
      LEFT JOIN categories parent ON parent.id = c.parent_id
      WHERE c.is_enabled = true AND c.slug <> 'video-podcast'
        AND (c.parent_id IS NULL OR parent.is_enabled = true)
      ORDER BY c.nav_sort_order NULLS LAST, c.name`),
  ]);
  if (!authorResult.rowCount) throw new Error("No active Super Admin or Admin account exists.");
  if (!categoryResult.rowCount) throw new Error("No enabled article categories were found.");

  const db = await pool.connect();
  let created = 0;
  try {
    await db.query("BEGIN");
    const imageKeys = await ensureAssets(db, authorResult.rows[0].id);
    for (let c = 0; c < categoryResult.rows.length; c += 1) {
      const category = categoryResult.rows[c];
      for (let i = 0; i < 10; i += 1) {
        const number = i + 1;
        const slug = `demo-${category.slug}-${String(number).padStart(2, "0")}`;
        const copy = articleCopy(category.name, topics[i], number);
        const imageKey = imageKeys[(i + c) % imageKeys.length];
        const inserted = await db.query(
          `INSERT INTO articles (slug,title,headline,summary,body,image_key,image_alt,category_id,status,author_id,published_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'published',$9,now()-($10::int * interval '1 hour'))
           ON CONFLICT (slug) DO NOTHING RETURNING id`,
          [slug, copy.title, copy.headline, copy.summary, copy.body, imageKey,
            `পরীক্ষামূলক ছবি ${((i+c)%imageKeys.length)+1}`, category.id, authorResult.rows[0].id, c*10+i],
        );
        if (!inserted.rowCount) continue;
        await db.query(
          "INSERT INTO test_seed_articles (article_id,category_id,seed_version) VALUES ($1,$2,'v1')",
          [inserted.rows[0].id, category.id],
        );
        created += 1;
      }
    }
    await db.query("COMMIT");
  } catch (error) {
    await db.query("ROLLBACK");
    throw error;
  } finally { db.release(); }
  console.log(`Created ${created} demo articles across ${categoryResult.rowCount} categories with ${assetCount} R2 images.`);
}

export async function removeTestArticles() {
  const db = await pool.connect();
  let deletedArticles = 0;
  const objectKeys = [];
  let deletedAssets = 0;
  let preservedAssets = 0;
  try {
    await db.query("BEGIN");
    const articles = await db.query(
      "DELETE FROM articles WHERE id IN (SELECT article_id FROM test_seed_articles) RETURNING id",
    );
    deletedArticles = articles.rowCount;
    const assets = await db.query(`SELECT tsa.media_asset_id,tsa.object_key
      FROM test_seed_assets tsa JOIN media_assets ma ON ma.id = tsa.media_asset_id
      WHERE NOT EXISTS (SELECT 1 FROM articles a WHERE a.image_key=tsa.object_key)
        AND NOT EXISTS (SELECT 1 FROM videos v WHERE v.object_key=tsa.object_key OR v.thumbnail_key=tsa.object_key)
      FOR UPDATE OF ma`);
    for (const asset of assets.rows) {
      objectKeys.push(asset.object_key);
      await db.query("DELETE FROM media_assets WHERE id=$1", [asset.media_asset_id]);
      deletedAssets += 1;
    }
    await db.query("DELETE FROM test_seed_assets");
    await db.query("COMMIT");
  } catch (error) {
    await db.query("ROLLBACK");
    throw error;
  } finally { db.release(); }

  const remaining = await pool.query("SELECT count(*)::int AS total FROM test_seed_assets");
  preservedAssets = remaining.rows[0].total;
  for (const Key of objectKeys) {
    await storage().send(new DeleteObjectCommand({ Bucket: config.media.bucket, Key }));
  }
  console.log(`Removed ${deletedArticles} demo articles and ${deletedAssets} unused R2 images. Preserved ${preservedAssets} referenced image(s).`);
}
