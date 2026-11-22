# অনুসন্ধান newsroom

A newsroom website and administration system deployed as three separate Dockploy services:

- **Frontend** — Nginx serves the public website and admin panel.
- **Backend** — Node.js/Express API, authentication, uploads and business logic.
- **PostgreSQL** — persistent application database.

The frontend proxies requests under `/api` and `/healthz` to the backend over the private Docker network. The browser therefore uses one origin for the site and API, preserving the existing session-cookie and CSRF model. Article images are stored in S3-compatible object storage (Cloudflare R2 recommended); they are not stored in the container.

## Deploy with Dockploy

Deploy the repository's **main** branch as a Docker Compose application, using the root `compose.yaml`. Do not create three independent Git deployments from the area-only branches: the Compose file builds all three services from the integrated main branch.

### Services

| Dockploy service | Container | Purpose |
|---|---|---|
| `frontend` | Nginx | Public website, admin UI, reverse proxy |
| `backend` | Node.js 22 | API, authentication, media signing, migrations |
| `postgres` | PostgreSQL 16 | Persistent database |

Expose only the frontend service publicly. Configure the Dockploy domain on `frontend` and set its container port to `80`. Keep `backend:3000` and `postgres:5432` private. The compose file creates a persistent `postgres_data` volume.

### Environment variables

Set these in the Dockploy Compose environment:

```dotenv
FRONTEND_PORT=8080
POSTGRES_DB=onusondhan
POSTGRES_USER=onusondhan
POSTGRES_PASSWORD=use-a-strong-url-safe-password
DATABASE_URL=postgres://onusondhan:use-a-strong-url-safe-password@postgres:5432/onusondhan
SESSION_SECRET=generate-at-least-32-random-characters
MEDIA_ENDPOINT=https://YOUR_CLOUDFLARE_ACCOUNT_ID.r2.cloudflarestorage.com
MEDIA_REGION=auto
MEDIA_BUCKET=your-r2-bucket
MEDIA_ACCESS_KEY_ID=your-r2-access-key-id
MEDIA_SECRET_ACCESS_KEY=your-r2-secret-access-key
MEDIA_PUBLIC_BASE_URL=https://your-public-media-domain
MEDIA_FORCE_PATH_STYLE=false
MEDIA_MAX_IMAGE_BYTES=10485760
```

Use a URL-safe PostgreSQL password in `DATABASE_URL` (or percent-encode reserved characters). Generate the session secret with `openssl rand -hex 32`. Keep all credentials in Dockploy environment settings, never in Git. The R2 public base URL must point to the public bucket/CDN hostname used to serve uploaded images. Configure R2 CORS to allow the deployed website origin to send browser `PUT` uploads with the required content-type header.

### Startup and health checks

- PostgreSQL becomes healthy after `pg_isready` succeeds.
- Backend waits for PostgreSQL, applies unapplied SQL migrations, then starts Express on port `3000`.
- Frontend waits for a healthy backend and serves on port `80`.
- Dockploy should monitor frontend port `80`; its `/healthz` route is proxied to the backend and checks database connectivity.

The backend migration runner tracks applied filenames in `schema_migrations`; existing migration files are not reapplied. Back up the database before deploying schema changes.

### First administrator

After all services are healthy, run this one-off command in the backend container:

```sh
npm run admin:create-superadmin
```

It prompts for the initial username, email and password. The password must be at least 12 characters. The command refuses to create a second initial Super Admin. The admin panel is available at `/admin` on the frontend domain.

## Local deployment test

Copy `.env.example` to `.env`, set the values above (including `DATABASE_URL=postgres://onusondhan:...@postgres:5432/onusondhan`), then run:

```sh
docker compose up --build -d
docker compose ps
docker compose logs -f backend
```

Open the frontend on port `8080` (or the configured `FRONTEND_PORT`). For a production Dockploy deployment, configure its public domain and TLS on the frontend service.

## Development

Requirements: Node.js 20+, PostgreSQL 13+ and an S3-compatible media bucket.

```sh
npm ci
npm run db:migrate
npm run admin:create-superadmin
npm start
```

Run checks with `npm run check` and tests with `npm test`.

## Branch responsibilities

- `main`: integrated deployable application and Compose orchestration.
- `frontend`: static public/admin UI, Nginx configuration and frontend image.
- `backend`: API, backend runtime image and operational scripts.
- `database`: SQL migrations and migration runner.

Make area-specific changes on their respective branches, then integrate them into `main` before deploying the Compose stack. The database itself is a runtime PostgreSQL service; the `database` branch contains schema and migration code, not a second application container.

## Security and operations

- Only the frontend should have a public domain/port. Do not publish backend or PostgreSQL ports.
- Keep PostgreSQL data in the named persistent volume and schedule backups.
- Keep R2 and database credentials private. Rotate any credentials that have been exposed.
- Set `TRUST_PROXY=1` because Express is behind the frontend reverse proxy.
- Set `MEDIA_FORCE_PATH_STYLE=false` for Cloudflare R2.
- The app serves all API requests from the same public origin; do not configure browser CORS or point frontend JavaScript directly at an internal backend hostname.
- The video-only category contains YouTube video links; uploaded article images are stored in R2.
