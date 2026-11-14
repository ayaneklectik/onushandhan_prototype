import { randomUUID } from "node:crypto";
import {
  DeleteObjectCommand,
  HeadObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import { PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { config } from "./config.js";
import { pool, recordActivity } from "./db.js";

const mediaConfig = config.media;
let client;

function storage() {
  if (!mediaConfig.bucket || !mediaConfig.accessKeyId || !mediaConfig.secretAccessKey) {
    const error = new Error("Media storage is not configured.");
    error.status = 503;
    throw error;
  }
  client ||= new S3Client({
    region: mediaConfig.region,
    endpoint: mediaConfig.endpoint,
    forcePathStyle: mediaConfig.forcePathStyle,
    credentials: {
      accessKeyId: mediaConfig.accessKeyId,
      secretAccessKey: mediaConfig.secretAccessKey,
    },
  });
  return client;
}

export function mediaUrl(key) {
  if (!key) return null;
  if (/^test-assets\/article-[1-8]\.svg$/.test(key)) return `/${key}`;
  if (!mediaConfig.publicBaseUrl) {
    const error = new Error("MEDIA_PUBLIC_BASE_URL is not configured.");
    error.status = 503;
    throw error;
  }
  return `${mediaConfig.publicBaseUrl.replace(/\/+$/, "")}/${key
    .split("/")
    .map(encodeURIComponent)
    .join("/")}`;
}

const MIME_TYPES = {
  image: new Set(["image/jpeg", "image/png", "image/webp", "image/avif"]),
};

const EXTENSIONS = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
  "image/avif": ".avif",
};

export async function createUpload(req, res) {
  const { mediaType, contentType, sizeBytes } = req.body;
  if (mediaType !== "image" || !MIME_TYPES.image.has(contentType)) {
    return res.status(400).json({ error: "Unsupported media type." });
  }
  const maxBytes = mediaConfig.maxImageBytes;
  if (!Number.isSafeInteger(sizeBytes) || sizeBytes < 1 || sizeBytes > maxBytes) {
    return res.status(400).json({ error: `File exceeds the ${maxBytes}-byte upload limit.` });
  }
  if (!mediaConfig.publicBaseUrl) {
    return res.status(503).json({ error: "Public media delivery is not configured." });
  }
  const s3 = storage();

  const key = `uploads/${req.user.id}/${randomUUID()}${EXTENSIONS[contentType]}`;
  const publicUrl = mediaUrl(key);
  const uploadUrl = await getSignedUrl(
    s3,
    new PutObjectCommand({
      Bucket: mediaConfig.bucket,
      Key: key,
      ContentType: contentType,
    }),
    { expiresIn: 600 },
  );
  const asset = await pool.query(
    `INSERT INTO media_assets (object_key, media_type, content_type, size_bytes, uploader_id)
     VALUES ($1, $2, $3, $4, $5) RETURNING id`,
    [key, mediaType, contentType, sizeBytes, req.user.id],
  );
  return res.status(201).json({
    assetId: asset.rows[0].id,
    objectKey: key,
    uploadUrl,
    uploadMethod: "PUT",
    contentType,
    publicUrl,
  });
}

export async function completeUpload(req, res) {
  if (!/^[\da-f]{8}-(?:[\da-f]{4}-){3}[\da-f]{12}$/i.test(req.params.id)) {
    return res.status(400).json({ error: "Invalid upload ID." });
  }
  const result = await pool.query(
    `SELECT id, object_key, content_type, size_bytes, uploader_id, status
     FROM media_assets WHERE id = $1`,
    [req.params.id],
  );
  const asset = result.rows[0];
  if (!asset) return res.status(404).json({ error: "Upload not found." });
  if (req.user.role === "moderator" && asset.uploader_id !== req.user.id) {
    return res.status(403).json({ error: "You can only complete your own uploads." });
  }
  if (asset.status === "ready") {
    return res.json({ id: asset.id, objectKey: asset.object_key, url: mediaUrl(asset.object_key) });
  }

  const head = await storage().send(
    new HeadObjectCommand({ Bucket: mediaConfig.bucket, Key: asset.object_key }),
  );
  if (head.ContentLength !== Number(asset.size_bytes) || head.ContentType !== asset.content_type) {
    return res.status(400).json({ error: "Uploaded file does not match the requested file details." });
  }
  const updated = await pool.query(
    "UPDATE media_assets SET status = 'ready' WHERE id = $1 RETURNING id, object_key",
    [asset.id],
  );
  return res.json({
    id: updated.rows[0].id,
    objectKey: updated.rows[0].object_key,
    url: mediaUrl(updated.rows[0].object_key),
  });
}

export async function deleteMedia(req, res) {
  if (!/^[\da-f]{8}-(?:[\da-f]{4}-){3}[\da-f]{12}$/i.test(req.params.id)) {
    return res.status(400).json({ error: "Invalid media ID." });
  }
  const result = await pool.query(
    "SELECT id, object_key, uploader_id, status FROM media_assets WHERE id = $1",
    [req.params.id],
  );
  const asset = result.rows[0];
  if (!asset) return res.status(404).json({ error: "Media asset not found." });
  if (req.user.role === "moderator" && asset.uploader_id !== req.user.id) {
    return res.status(403).json({ error: "You can only remove your own media." });
  }
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const locked = await client.query(
      "SELECT id, object_key, status FROM media_assets WHERE id = $1 FOR UPDATE",
      [asset.id],
    );
    if (!locked.rowCount) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Media asset not found." });
    }
    const references = await client.query(
      `SELECT
         EXISTS (SELECT 1 FROM articles WHERE image_key = $1) AS article_image,
         EXISTS (SELECT 1 FROM videos WHERE object_key = $1 OR thumbnail_key = $1) AS video_media`,
      [asset.object_key],
    );
    if (references.rows[0].article_image || references.rows[0].video_media) {
      await client.query("ROLLBACK");
      return res.status(409).json({ error: "This media is in use. Replace or remove its content first." });
    }
    if (locked.rows[0].status === "ready" && !/^test-assets\/article-[1-8]\.svg$/.test(locked.rows[0].object_key)) {
      await storage().send(new DeleteObjectCommand({ Bucket: mediaConfig.bucket, Key: asset.object_key }));
    }
    await client.query("DELETE FROM media_assets WHERE id = $1", [asset.id]);
    await recordActivity(client, req.user.id, "deleted", "media", asset.id);
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    if (error.code === "23503") {
      return res.status(409).json({ error: "This media is still in use. Replace or remove its content first." });
    }
    throw error;
  } finally {
    client.release();
  }
  return res.json({ ok: true });
}

export function youtubeVideoId(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    return null;
  }
  if (url.protocol !== "https:" || (url.port && url.port !== "443")) return null;

  const hostname = url.hostname.toLowerCase();
  const parts = url.pathname.split("/").filter(Boolean);
  let id = null;
  if (hostname === "youtu.be") {
    id = parts[0];
  } else if (["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com"].includes(hostname)) {
    id = url.pathname === "/watch" ? url.searchParams.get("v") : ["embed", "shorts", "live", "v"].includes(parts[0]) ? parts[1] : null;
  }
  return id && /^[\w-]{11}$/.test(id) ? id : null;
}

export function validYoutubeVideoUrl(value) {
  return youtubeVideoId(value) !== null;
}
