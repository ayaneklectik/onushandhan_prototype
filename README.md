# অনুসন্ধান newsroom

Newsroom website and administration system. Production runs as **three separate Dokploy services**:

1. **frontend** — Nginx serves the public website and admin panel.
2. **backend** — Node.js 22 / Express API, authentication, media signing and database migrations.
3. **postgres** — PostgreSQL 18 database with persistent storage.

The frontend proxies `/api` and `/healthz` to the backend. The browser uses one origin for the website and API, preserving the existing session-cookie and CSRF behavior. Article images are stored in Cloudflare R2 (S3-compatible), not in the application containers.

## Dokploy deployment — separate services

Deploy from **`main`**. The `frontend`, `backend`, and `database` branches are historical area branches; they are not the production deployment targets. The integrated application and both production Dockerfiles are already in `main`. Do not merge the old area branches over `main`.

All three services must run on the same Dokploy server and share a Docker network. Dokploy's default `dokploy-network` is sufficient: services on it can resolve one another by service name. Keep the database off public domains/ports.

### 1. PostgreSQL service

Create a Dokploy **Database → PostgreSQL** service:

- Use the **Internal Host** and **Internal Connection URL** shown in the PostgreSQL service's General tab. The hostname may be generated from the Dokploy service name; copy the displayed value exactly.
- Version: PostgreSQL 18
- Database: `onusondhan` (or your chosen name)
- Username: `onusondhan` (or your chosen name)
- Password: generate a strong password and save it securely
- Persistent storage: enabled
- Public exposure / domain: **disabled**
- Internal port: `5432`

Use the actual database name, username and password shown by Dokploy in the backend's `DATABASE_URL`. Do not publish port 5432 to the internet. Keep this service on `dokploy-network`.

### 2. Backend application

Create a separate Dokploy **Application** from this Git repository:

- Repository: `ayaneklectik/onushandhan_prototype`
- Branch: `main`
- Build type: **Dockerfile**
- Build context / root directory: repository root (`/`)
- Dockerfile path: `Dockerfile.backend`
- Internal application port: `3000`
- Public domain: **none**
- Network: `dokploy-network`
- Service name / network hostname: `backend`

Set these environment variables on the backend:

```dotenv
NODE_ENV=production
PORT=3000
TRUST_PROXY=1
AUTO_MIGRATE=false
DATABASE_URL=PASTE_THE_POSTGRES_INTERNAL_CONNECTION_URL_FROM_DOKPLOY
SESSION_SECRET=GENERATE_AT_LEAST_32_RANDOM_CHARACTERS
MEDIA_ENDPOINT=https://YOUR_CLOUDFLARE_ACCOUNT_ID.r2.cloudflarestorage.com
MEDIA_REGION=auto
MEDIA_BUCKET=YOUR_R2_BUCKET
MEDIA_ACCESS_KEY_ID=YOUR_R2_ACCESS_KEY_ID
MEDIA_SECRET_ACCESS_KEY=YOUR_R2_SECRET_ACCESS_KEY
MEDIA_PUBLIC_BASE_URL=https://YOUR_PUBLIC_MEDIA_DOMAIN
MEDIA_FORCE_PATH_STYLE=false
MEDIA_MAX_IMAGE_BYTES=10485760
```

Paste the PostgreSQL service's **Internal Connection URL** exactly as Dokploy displays it; do not guess the hostname. Generate the session secret with `openssl rand -hex 32`. Never commit real credentials to Git.

The frontend's Nginx config targets `http://backend:3000`; therefore the backend must be reachable on the shared network under the hostname `backend`. Keep `AUTO_MIGRATE=false` until the Railway database dump has been restored and checked.

### 3. Frontend application

Create another Dokploy **Application** from the same repository:

- Repository: `ayaneklectik/onushandhan_prototype`
- Branch: `main`
- Build type: **Dockerfile**
- Build context / root directory: repository root (`/`)
- Dockerfile path: `Dockerfile.frontend`
- Container port: `80`
- Network: `dokploy-network`
- Public domain: attach the website domain here
- Service name: `frontend`

The frontend has no application environment variables. It serves the static files and proxies API and health-check requests to `backend:3000`. Do not configure a separate public backend domain; the API is intentionally same-origin through Nginx.

### 4. Restore the Railway PostgreSQL dump

The local backup `railway_backup.sql` is a PostgreSQL 18.7 **plain SQL** dump. Restore it into the fresh Dokploy PostgreSQL database before enabling migrations.

1. Keep the frontend out of public traffic until the restore and checks are complete.
2. Ensure the PostgreSQL service is healthy and the backend has `AUTO_MIGRATE=false`.
3. Transfer the SQL dump securely from your Mac to the VPS, or use a secure database tunnel. Do not commit the dump or put it in a public directory.
4. Import the plain SQL dump into the empty `onusondhan` database using `psql`. Do not use `pg_restore` for this plain SQL file.
5. Verify the expected tables, article/user counts, and `schema_migrations` entries for migrations 001–008. Do not import the dump a second time into a populated database.
6. Only after the restore is verified, change backend `AUTO_MIGRATE=true` and redeploy the backend. The migration runner recognizes the historical `001_initial.sql` ledger entry and will not replay the initial schema.

Take a database backup before any later schema migration.

### 5. Verify the deployment

- Backend health check: `http://backend:3000/healthz` from the shared network; it checks PostgreSQL connectivity.
- Frontend health check: `/healthz` on the public frontend domain; Nginx proxies it to the backend.
- Confirm the homepage, article pages, admin login, and R2 image delivery.
- Test an authenticated image upload and confirm the object appears in R2 and loads from `MEDIA_PUBLIC_BASE_URL`.
- Only the frontend should have a public domain. Backend port 3000 and PostgreSQL port 5432 remain internal.

### First administrator

The Railway snapshot should already contain the existing users. Do not create a new Super Admin unless the restored database has none. If a new initial Super Admin is genuinely needed, run this one-off command in the backend container:

```sh
npm run admin:create-superadmin
```

It prompts for a username, email and password. The password must be at least 12 characters. The script refuses to create another initial Super Admin if one already exists. The admin panel is available at `/admin` on the frontend domain.

## Local checks

Requirements: Node.js 20+, PostgreSQL 18 and an S3-compatible media bucket.

```sh
npm ci
npm run check
npm test
```

For local Docker testing only, the root `compose.yaml` starts all three components together. **Do not deploy that Compose stack in Dokploy for this production setup**; create the three independent services using the settings above.

## Repository layout

- `main`: integrated application and production deployment files.
- `Dockerfile.frontend`: Nginx frontend image.
- `Dockerfile.backend`: Node.js API image.
- `nginx/default.conf`: same-origin API and health-check proxy.
- `server/`: API, authentication, database and media code.
- `migrations/`: ordered SQL migrations and migration runner.
- `frontend`, `backend`, `database`: historical area branches, not deployment branches.

## Security and operations

- Never expose PostgreSQL or the backend directly to the public internet.
- Keep database credentials, session secret and R2 credentials in Dokploy environment settings.
- Keep PostgreSQL data on persistent storage and schedule backups.
- Use `TRUST_PROXY=1` behind Dokploy's reverse proxy.
- Set `MEDIA_FORCE_PATH_STYLE=false` for Cloudflare R2.
- Configure the R2 bucket CORS policy to allow the frontend origin to perform browser `PUT` uploads with the required content-type header.
- Do not configure browser JavaScript to call the backend's private hostname; all browser API calls use the frontend's same-origin `/api` path.
