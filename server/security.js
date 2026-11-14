import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { config } from "./config.js";

export function newToken() {
  return randomBytes(32).toString("base64url");
}

export function hashToken(token) {
  return createHash("sha256").update(token).digest("hex");
}

export function signCookie(value) {
  return createHmac("sha256", config.sessionSecret).update(value).digest("base64url");
}

export function safeEqual(left, right) {
  if (typeof left !== "string" || typeof right !== "string") {
    return false;
  }
  const a = Buffer.from(left);
  const b = Buffer.from(right);
  return a.length === b.length && timingSafeEqual(a, b);
}

export function sessionCookieValue(token) {
  return `${token}.${signCookie(token)}`;
}

export function verifySessionCookie(value) {
  if (typeof value !== "string") {
    return null;
  }
  const separator = value.lastIndexOf(".");
  if (separator <= 0) {
    return null;
  }
  const token = value.slice(0, separator);
  const signature = value.slice(separator + 1);
  return safeEqual(signCookie(token), signature) ? token : null;
}
