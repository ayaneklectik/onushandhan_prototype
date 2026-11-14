import "dotenv/config";

const isProduction = process.env.NODE_ENV === "production";

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const config = {
  isProduction,
  port: Number.parseInt(process.env.PORT || "3000", 10),
  databaseUrl: required("DATABASE_URL"),
  sessionSecret: required("SESSION_SECRET"),
  trustProxy: process.env.TRUST_PROXY === "1",
  media: {
    endpoint: process.env.MEDIA_ENDPOINT || undefined,
    region: process.env.MEDIA_REGION || "auto",
    bucket: process.env.MEDIA_BUCKET || undefined,
    accessKeyId: process.env.MEDIA_ACCESS_KEY_ID || undefined,
    secretAccessKey: process.env.MEDIA_SECRET_ACCESS_KEY || undefined,
    publicBaseUrl: process.env.MEDIA_PUBLIC_BASE_URL || undefined,
    forcePathStyle: process.env.MEDIA_FORCE_PATH_STYLE === "true",
    maxImageBytes: Number.parseInt(process.env.MEDIA_MAX_IMAGE_BYTES || "10485760", 10),
  },
};

if (config.sessionSecret.length < 32) {
  throw new Error("SESSION_SECRET must contain at least 32 characters.");
}

if (isProduction && !config.media.bucket) {
  throw new Error("MEDIA_BUCKET must be configured in production.");
}
if (isProduction && (!config.media.publicBaseUrl || !config.media.accessKeyId || !config.media.secretAccessKey)) {
  throw new Error("MEDIA_PUBLIC_BASE_URL and S3-compatible media credentials must be configured in production.");
}
