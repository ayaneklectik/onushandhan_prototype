import test from "node:test";
import assert from "node:assert/strict";

process.env.NODE_ENV = "test";
process.env.DATABASE_URL = "postgresql://localhost:5432/test";
process.env.SESSION_SECRET = "unit-test-session-secret-with-more-than-32-characters";

const { mediaUrl, validYoutubeVideoUrl, youtubeVideoId } = await import("../server/media.js");

test("generated local article artwork does not require remote media storage", () => {
  assert.equal(mediaUrl("test-assets/article-1.svg"), "/test-assets/article-1.svg");
  assert.equal(mediaUrl("test-assets/article-8.svg"), "/test-assets/article-8.svg");
});

test("YouTube links produce IDs for supported video URL formats", () => {
  const cases = [
    ["https://www.youtube.com/watch?v=dQw4w9WgXcQ", "dQw4w9WgXcQ"],
    ["https://youtu.be/dQw4w9WgXcQ?t=10", "dQw4w9WgXcQ"],
    ["https://youtube.com/shorts/dQw4w9WgXcQ", "dQw4w9WgXcQ"],
    ["https://m.youtube.com/live/dQw4w9WgXcQ", "dQw4w9WgXcQ"],
  ];
  for (const [url, id] of cases) {
    assert.equal(youtubeVideoId(url), id);
    assert.equal(validYoutubeVideoUrl(url), true);
  }
});

test("video links reject non-YouTube, insecure, and non-video URLs", () => {
  for (const url of [
    "https://vimeo.com/123456",
    "http://youtube.com/watch?v=dQw4w9WgXcQ",
    "https://youtube.com.example.org/watch?v=dQw4w9WgXcQ",
    "https://youtube.com/playlist?list=PL123",
    "not a URL",
  ]) {
    assert.equal(youtubeVideoId(url), null);
    assert.equal(validYoutubeVideoUrl(url), false);
  }
});
