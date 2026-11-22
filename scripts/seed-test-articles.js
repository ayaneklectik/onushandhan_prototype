import { seedTestArticles } from "./test-article-seed.js";
import { pool } from "../server/db.js";

try {
  await seedTestArticles();
} catch (error) {
  console.error("Test article seeding failed:", error);
  process.exitCode = 1;
} finally {
  await pool.end();
}
