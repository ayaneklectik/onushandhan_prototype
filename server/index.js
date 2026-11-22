import path from "node:path";
import { fileURLToPath } from "node:url";
import express from "express";
import helmet from "helmet";
import { rateLimit } from "express-rate-limit";
import { config } from "./config.js";
import { pool } from "./db.js";
import {
  csrfToken,
  currentUser,
  loadSession,
  login,
  logout,
  requireRoles,
  verifySameOrigin,
} from "./auth.js";
import { api } from "./routes.js";
import { completeUpload, createUpload, deleteMedia } from "./media.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const app = express();
const s3Origin = config.media.endpoint
  ? new URL(config.media.endpoint).origin
  : config.media.bucket
    ? `https://${config.media.bucket}.s3.${config.media.region}.amazonaws.com`
    : null;
const mediaPublicOrigin = config.media.publicBaseUrl ? new URL(config.media.publicBaseUrl).origin : null;
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: "draft-8",
  legacyHeaders: false,
  message: { error: "Too many sign-in attempts. Try again in 15 minutes." },
});

app.disable("x-powered-by");
app.set("trust proxy", config.trustProxy ? 1 : false);
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        baseUri: ["'self'"],
        connectSrc: ["'self'", ...(s3Origin ? [s3Origin] : [])],
        fontSrc: ["'self'", "https://fonts.gstatic.com"],
        formAction: ["'self'"],
        frameSrc: ["https://www.youtube-nocookie.com"],
        frameAncestors: ["'none'"],
        imgSrc: ["'self'", "data:", "https:", ...(mediaPublicOrigin ? [mediaPublicOrigin] : [])],
        objectSrc: ["'none'"],
        scriptSrc: ["'self'"],
        styleSrc: ["'self'", "https://fonts.googleapis.com"],
        ...(config.isProduction ? { upgradeInsecureRequests: [] } : {}),
      },
    },
    crossOriginEmbedderPolicy: false,
    referrerPolicy: { policy: "strict-origin-when-cross-origin" },
  }),
);
app.use(express.json({ limit: "1mb", strict: true }));
app.use(
  "/api",
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 300,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    message: { error: "Too many requests. Try again later." },
  }),
);
app.use("/api", loadSession);
app.use("/api", verifySameOrigin);
app.use(["/api/admin", "/api/auth", "/api/csrf"], (_req, res, next) => {
  res.setHeader("Cache-Control", "no-store");
  return next();
});

app.use(async (req, res, next) => {
  const adminPath = req.path === "/admin" || req.path === "/admin.html" ||
    req.path.startsWith("/api/admin/") || req.path === "/api/admin" ||
    req.path.startsWith("/api/auth/") || req.path === "/api/csrf" ||
    req.path === "/healthz" || req.path === "/admin.css" || req.path === "/admin.js" ||
    req.path === "/onusondhan-logo.png";
  if (adminPath) return next();
  try {
    const result = await pool.query(
      "SELECT setting_value FROM site_settings WHERE setting_key = 'maintenance_mode' LIMIT 1",
    );
    if (result.rows[0]?.setting_value !== "true") return next();
    res.set({
      "Cache-Control": "no-store, no-cache, must-revalidate",
      "X-Robots-Tag": "noindex, nofollow, noarchive",
      "Retry-After": "1800",
    });
    if (req.path.startsWith("/api/")) {
      return res.status(503).json({ error: "The website is temporarily under maintenance.", maintenance: true });
    }
    return res.status(503).sendFile(path.join(root, "maintenance.html"), (error) => {
      if (error && !res.headersSent) res.status(503).type("text").send("অনুসন্ধান — রক্ষণাবেক্ষণ চলছে।");
    });
  } catch (error) {
    return next(error);
  }
});

app.get("/healthz", async (_req, res, next) => {
  try {
    await pool.query("SELECT 1");
    return res.json({ status: "ok" });
  } catch (error) {
    return next(error);
  }
});

app.get("/api/csrf", csrfToken);
app.post("/api/auth/login", loginLimiter, login);
app.post("/api/auth/logout", logout);
app.get("/api/auth/me", currentUser);

app.post("/api/admin/media/uploads", requireRoles("super_admin", "admin", "moderator"), createUpload);
app.post(
  "/api/admin/media/uploads/:id/complete",
  requireRoles("super_admin", "admin", "moderator"),
  completeUpload,
);
app.delete("/api/admin/media/uploads/:id", requireRoles("super_admin", "admin", "moderator"), deleteMedia);
app.use("/api", api);

app.get("/admin.html", (_req, res) => res.redirect(308, "/admin"));
app.get("/admin", (_req, res, next) => {
  res.sendFile(path.join(root, "admin.html"), (error) => {
    if (error) next(error);
  });
});

const publicFiles = new Set([
  "/",
  "/index.html",
  "/styles.css",
  "/app.js",
  "/content.js",
  "/onusondhan-logo.png",
  "/admin.css",
  "/admin.js",
  "/article.html",
  "/article.js",
  "/test-assets/article-1.svg",
  "/test-assets/article-2.svg",
  "/test-assets/article-3.svg",
  "/test-assets/article-4.svg",
  "/test-assets/article-5.svg",
  "/test-assets/article-6.svg",
  "/test-assets/article-7.svg",
  "/test-assets/article-8.svg",
]);
app.use((req, res, next) => {
  if (!publicFiles.has(req.path)) return next();
  const filename = req.path === "/" ? "index.html" : req.path.slice(1);
  return res.sendFile(path.join(root, filename), (error) => {
    if (error) next(error);
  });
});

app.use("/api", (_req, res) => res.status(404).json({ error: "API endpoint not found." }));
app.use((_req, res) => res.status(404).type("text").send("Page not found."));

app.use((error, _req, res, next) => {
  if (res.headersSent) return next(error);
  if (error?.type === "entity.too.large") {
    return res.status(413).json({ error: "Request body is too large." });
  }
  if (error?.type === "entity.parse.failed") {
    return res.status(400).json({ error: "Request body must be valid JSON." });
  }
  if (error?.code === "23505") {
    return res.status(409).json({ error: "A record with the same unique value already exists." });
  }
  if (error?.status && error.status < 500) {
    return res.status(error.status).json({ error: error.message });
  }
  console.error("Request failed:", error);
  return res.status(500).json({
    error: config.isProduction ? "The request could not be completed." : error.message,
  });
});

const server = app.listen(config.port, () => {
  console.log(`Onusondhan server listening on port ${config.port}`);
});

async function shutdown(signal) {
  console.log(`Received ${signal}; shutting down.`);
  server.close(async () => {
    await pool.end();
    process.exit(0);
  });
}

process.once("SIGTERM", () => void shutdown("SIGTERM"));
process.once("SIGINT", () => void shutdown("SIGINT"));
