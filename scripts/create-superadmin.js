import readline from "node:readline/promises";
import { stdin, stdout } from "node:process";
import bcrypt from "bcryptjs";
import { pool } from "../server/db.js";
import { recordActivity } from "../server/db.js";

const rl = readline.createInterface({ input: stdin, output: stdout });

try {
  const username = (await rl.question("Super Admin username: ")).trim();
  const email = (await rl.question("Super Admin email: ")).trim().toLowerCase();
  const password = await rl.question("Super Admin password (minimum 12 characters): ");
  if (!/^[a-zA-Z0-9._-]{3,48}$/.test(username)) {
    throw new Error("Username must be 3–48 characters and use letters, numbers, '.', '_' or '-'.");
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error("Enter a valid email address.");
  }
  if (password.length < 12 || Buffer.byteLength(password, "utf8") > 72) {
    throw new Error("Password must contain at least 12 characters and no more than 72 UTF-8 bytes.");
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT pg_advisory_xact_lock(142857, 1)");
    const exists = await client.query("SELECT 1 FROM users WHERE role = 'super_admin' LIMIT 1");
    if (exists.rowCount) {
      throw new Error("A Super Admin already exists. Use the user management panel to manage accounts.");
    }
    const created = await client.query(
      `INSERT INTO users (username, email, password_hash, role)
       VALUES ($1, $2, $3, 'super_admin')
       RETURNING id, username`,
      [username, email, passwordHash],
    );
    await recordActivity(
      client,
      created.rows[0].id,
      "created",
      "user",
      created.rows[0].id,
      { role: "super_admin", bootstrap: true },
    );
    await client.query("COMMIT");
    console.log(`Created Super Admin account "${created.rows[0].username}".`);
  } catch (error) {
    await client.query("ROLLBACK");
    if (error.code === "23505") {
      throw new Error("That username or email address is already in use.");
    }
    throw error;
  } finally {
    client.release();
  }
} catch (error) {
  console.error(error.message || error);
  process.exitCode = 1;
} finally {
  rl.close();
  await pool.end();
}
