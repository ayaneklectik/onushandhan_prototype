import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { pool } from "../server/db.js";

const directory = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../migrations");
const client = await pool.connect();

// The Railway snapshot predates a harmless migration filename clarification.
// Preserve its original ledger entry so the initial schema is never replayed.
const historicalNames = {
  "001_initial_schema.sql": "001_initial.sql",
};

try {
  await client.query("BEGIN");
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      filename TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
  const files = (await readdir(directory)).filter((file) => /^\d+_.+\.sql$/.test(file)).sort();
  for (const filename of files) {
    const historicalName = historicalNames[filename];
    const alreadyApplied = await client.query(
      historicalName
        ? "SELECT 1 FROM schema_migrations WHERE filename IN ($1, $2) LIMIT 1"
        : "SELECT 1 FROM schema_migrations WHERE filename = $1",
      historicalName ? [filename, historicalName] : [filename],
    );
    if (alreadyApplied.rowCount) {
      console.log(`Skipping already-applied ${filename}`);
      continue;
    }
    const migration = await readFile(path.join(directory, filename), "utf8");
    await client.query(migration);
    await client.query("INSERT INTO schema_migrations (filename) VALUES ($1)", [filename]);
    console.log(`Applied ${filename}`);
  }
  await client.query("COMMIT");
} catch (error) {
  await client.query("ROLLBACK");
  console.error("Database migration failed:", error);
  process.exitCode = 1;
} finally {
  client.release();
  await pool.end();
}
