import test from "node:test";
import assert from "node:assert/strict";

process.env.NODE_ENV = "test";
process.env.DATABASE_URL = "postgres://test:test@localhost:5432/test";
process.env.SESSION_SECRET = "unit-test-session-secret-with-more-than-32-characters";

const { hashToken, newToken, sessionCookieValue, verifySessionCookie } = await import("../server/security.js");
const { requireRoles, verifySameOrigin } = await import("../server/auth.js");

function response() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

function request(overrides = {}) {
  const headers = {
    host: "news.example",
    origin: "https://news.example",
    "x-csrf-token": "valid-csrf-token",
    cookie: "onusondhan_csrf=valid-csrf-token",
    ...overrides.headers,
  };
  return {
    method: "POST",
    protocol: "https",
    headers,
    session: null,
    get(name) {
      return headers[name.toLowerCase()];
    },
    ...overrides,
  };
}

test("session cookies are signed and tampering is rejected", () => {
  const token = newToken();
  const cookie = sessionCookieValue(token);
  assert.equal(verifySessionCookie(cookie), token);
  assert.equal(verifySessionCookie(`${cookie}x`), null);
  assert.notEqual(hashToken(token), token);
});

test("role middleware rejects unauthenticated and insufficient roles", () => {
  const middleware = requireRoles("super_admin");
  const unauthenticated = response();
  middleware(request(), unauthenticated, () => assert.fail("Unauthenticated request was allowed."));
  assert.equal(unauthenticated.statusCode, 401);

  const moderator = response();
  middleware(
    request({ user: { id: "moderator-id", role: "moderator" } }),
    moderator,
    () => assert.fail("Moderator received Super Admin access."),
  );
  assert.equal(moderator.statusCode, 403);

  const superAdmin = response();
  let allowed = false;
  middleware(
    request({ user: { id: "super-id", role: "super_admin" } }),
    superAdmin,
    () => { allowed = true; },
  );
  assert.equal(allowed, true);
});

test("mutating requests require same origin and matching CSRF tokens", () => {
  const noOrigin = response();
  verifySameOrigin(request({ headers: { origin: undefined } }), noOrigin, () => assert.fail("Missing origin was allowed."));
  assert.equal(noOrigin.statusCode, 403);

  const crossOrigin = response();
  verifySameOrigin(
    request({ headers: { origin: "https://attacker.example" } }),
    crossOrigin,
    () => assert.fail("Cross-origin request was allowed."),
  );
  assert.equal(crossOrigin.statusCode, 403);

  const mismatchedToken = response();
  verifySameOrigin(
    request({ headers: { "x-csrf-token": "different-token" } }),
    mismatchedToken,
    () => assert.fail("Mismatched CSRF token was allowed."),
  );
  assert.equal(mismatchedToken.statusCode, 403);

  const authenticatedMismatch = response();
  verifySameOrigin(
    request({
      user: { id: "user-id", role: "admin" },
      session: { csrfHash: hashToken("another-token") },
    }),
    authenticatedMismatch,
    () => assert.fail("Session-unbound CSRF token was allowed."),
  );
  assert.equal(authenticatedMismatch.statusCode, 403);

  const valid = response();
  let allowed = false;
  verifySameOrigin(
    request({
      user: { id: "user-id", role: "admin" },
      session: { csrfHash: hashToken("valid-csrf-token") },
    }),
    valid,
    () => { allowed = true; },
  );
  assert.equal(allowed, true);
});
