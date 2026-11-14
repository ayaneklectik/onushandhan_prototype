import { removeTestArticles } from "./test-article-seed.js";
import { pool } from "../server/db.js";

try {
  await removeTestArticles();
} catch (error) {
  console.error("Test article cleanup failed:", error);
  process.exitCode = 1;
} finally {
  await pool.end();
}
