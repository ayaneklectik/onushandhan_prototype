import { randomUUID } from "node:crypto";
import bcrypt from "bcryptjs";
import { pool, recordActivity } from "./db.js";
import { config } from "./config.js";
import { hashToken, newToken, safeEqual, sessionCookieValue, verifySessionCookie } from "./security.js";

const SESSION_TTL_MS = 8 * 60 * 60 * 1000;
const COOKIE_SECURE = config.isProduction ? "; Secure" : "";
const SESSION_COOKIE = "onusondhan_session";
const CSRF_COOKIE = "onusondhan_csrf";

function cookies(req) {
  const result = {};
  for (const part of (req.headers.cookie || "").split(";")) {
    const separator = part.indexOf("=");
    if (separator <= 0) continue;
    const name = part.slice(0, separator).trim();
    try {
      result[name] = decodeURIComponent(part.slice(separator + 1).trim());
    } catch {
      result[name] = "";
    }
  }
  return result;
}

function setSessionCookies(res, token, csrfToken) {
  const age = Math.floor(SESSION_TTL_MS / 1000);
  res.append(
    "Set-Cookie",
    `${SESSION_COOKIE}=${encodeURIComponent(sessionCookieValue(token))}; Path=/; HttpOnly; SameSite=Strict; Max-Age=${age}${COOKIE_SECURE}`,
  );
  res.append(
    "Set-Cookie",
    `${CSRF_COOKIE}=${encodeURIComponent(csrfToken)}; Path=/; SameSite=Strict; Max-Age=${age}${COOKIE_SECURE}`,
  );
}

export function clearSessionCookies(res) {
  res.append(
    "Set-Cookie",
    `${SESSION_COOKIE}=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0${COOKIE_SECURE}`,
  );
  res.append("Set-Cookie", `${CSRF_COOKIE}=; Path=/; SameSite=Strict; Max-Age=0${COOKIE_SECURE}`);
}

export async function loadSession(req, _res, next) {
  try {
    const raw = cookies(req)[SESSION_COOKIE];
    const token = verifySessionCookie(raw);
    if (!token) {
      req.user = null;
      req.session = null;
      return next();
    }

    const result = await pool.query(
      `SELECT s.id AS session_id, s.csrf_hash, s.expires_at,
              u.id, u.username, u.email, u.role, u.status
       FROM admin_sessions s
       JOIN users u ON u.id = s.user_id
       WHERE s.token_hash = $1 AND s.expires_at > now()`,
      [hashToken(token)],
    );
    if (!result.rowCount || result.rows[0].status !== "active") {
      if (result.rowCount) {
        await pool.query("DELETE FROM admin_sessions WHERE id = $1", [result.rows[0].session_id]);
      }
      clearSessionCookies(_res);
      req.user = null;
      req.session = null;
      return next();
    }

    const row = result.rows[0];
    req.user = {
      id: row.id,
      username: row.username,
      email: row.email,
      role: row.role,
    };
    req.session = { id: row.session_id, csrfHash: row.csrf_hash };
    await pool.query("UPDATE admin_sessions SET last_seen_at = now() WHERE id = $1", [row.session_id]);
    return next();
  } catch (error) {
    return next(error);
  }
}

export function requireAuth(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ error: "Authentication required." });
  }
  return next();
}

export function requireRoles(...roles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: "Authentication required." });
    }
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: "You do not have permission to perform this action." });
    }
    return next();
  };
}

export function verifySameOrigin(req, res, next) {
  if (["GET", "HEAD", "OPTIONS"].includes(req.method)) {
    return next();
  }

  const origin = req.get("origin");
  if (!origin) {
    return res.status(403).json({ error: "A same-origin request is required." });
  }
  try {
    const parsedOrigin = new URL(origin);
    if (
      parsedOrigin.host !== req.get("host") ||
      parsedOrigin.protocol !== `${req.protocol}:`
    ) {
      return res.status(403).json({ error: "A same-origin request is required." });
    }
  } catch {
    return res.status(403).json({ error: "Invalid request origin." });
  }

  const cookie = cookies(req)[CSRF_COOKIE];
  const header = req.get("x-csrf-token");
  if (!cookie || !header || !safeEqual(cookie, header)) {
    return res.status(403).json({ error: "Invalid CSRF token." });
  }
  if (req.session && !safeEqual(hashToken(header), req.session.csrfHash)) {
    return res.status(403).json({ error: "Invalid CSRF token." });
  }
  return next();
}

export async function csrfToken(req, res) {
  let token = cookies(req)[CSRF_COOKIE];
  if (req.session && (!token || !safeEqual(hashToken(token), req.session.csrfHash))) {
    token = newToken();
    await pool.query("UPDATE admin_sessions SET csrf_hash = $1 WHERE id = $2", [
      hashToken(token),
      req.session.id,
    ]);
  } else if (!token) {
    token = newToken();
  }
  res.append(
    "Set-Cookie",
    `${CSRF_COOKIE}=${encodeURIComponent(token)}; Path=/; SameSite=Strict; Max-Age=${Math.floor(SESSION_TTL_MS / 1000)}${COOKIE_SECURE}`,
  );
  return res.json({ csrfToken: token });
}

export async function login(req, res) {
  const username = typeof req.body.username === "string" ? req.body.username.trim() : null;
  const password = req.body.password;
  if (typeof username !== "string" || typeof password !== "string") {
    return res.status(400).json({ error: "Username and password are required." });
  }
  if (Buffer.byteLength(password, "utf8") > 72) {
    return res.status(400).json({ error: "Password must not exceed 72 UTF-8 bytes." });
  }

  const result = await pool.query(
    `SELECT id, username, email, password_hash, role, status
     FROM users WHERE lower(username) = lower($1) OR lower(email) = lower($1)`,
    [username],
  );
  const user = result.rows[0];
  const passwordMatches = user
    ? await bcrypt.compare(password, user.password_hash)
    : await bcrypt.compare(password, "$2b$12$CFAd4ZV2hjf/W2My9A5Y9epONDrrMDcUAiO7BZGR3f4wKRpyLdC0.");
  if (!user || !passwordMatches || user.status !== "active") {
    return res.status(401).json({ error: "Invalid username or password." });
  }

  const token = newToken();
  const csrf = newToken();
  const expiresAt = new Date(Date.now() + SESSION_TTL_MS);
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("DELETE FROM admin_sessions WHERE expires_at <= now()");
    await client.query(
      "INSERT INTO admin_sessions (token_hash, csrf_hash, user_id, expires_at) VALUES ($1, $2, $3, $4)",
      [hashToken(token), hashToken(csrf), user.id, expiresAt],
    );
    await client.query("UPDATE users SET last_login_at = now() WHERE id = $1", [user.id]);
    await recordActivity(client, user.id, "login", "session", randomUUID());
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }

  setSessionCookies(res, token, csrf);
  return res.json({
    user: { id: user.id, username: user.username, email: user.email, role: user.role },
    csrfToken: csrf,
  });
}

export async function logout(req, res) {
  if (req.session) {
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      await client.query("DELETE FROM admin_sessions WHERE id = $1", [req.session.id]);
      await recordActivity(client, req.user.id, "logout", "session", req.session.id);
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }
  clearSessionCookies(res);
  return res.json({ ok: true });
}

export async function currentUser(req, res) {
  if (!req.user) {
    return res.status(401).json({ error: "Authentication required." });
  }
  return res.json({
    user: req.user,
    csrfToken: cookies(req)[CSRF_COOKIE] || "",
  });
}
