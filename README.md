# অনুসন্ধান newsroom

The public website and administration panel are served by the same Node.js process. PostgreSQL stores content, accounts, sessions, permissions, settings, and activity; article images are held in S3-compatible object storage. Videos are added as YouTube links.

## Requirements

- Node.js 20 or newer
- PostgreSQL 13 or newer
- An S3-compatible bucket for public article images
- A same-origin HTTPS deployment for production

## First-time setup

1. Create a PostgreSQL database and copy `.env.example` to `.env`.
2. Set `DATABASE_URL` and generate a unique session key, for example:

   ```sh
   openssl rand -hex 32
   ```

3. Configure media storage:
   - Set `MEDIA_BUCKET`, `MEDIA_REGION`, `MEDIA_ACCESS_KEY_ID`, and `MEDIA_SECRET_ACCESS_KEY`.
   - Set `MEDIA_ENDPOINT` for S3-compatible providers that need a custom endpoint.
   - Set `MEDIA_PUBLIC_BASE_URL` to the public base URL/CDN path for objects in the bucket.
   - In the bucket's CORS policy, allow the deployed website origin to use `POST` with the headers required by S3 POST policies. For local development, also allow `http://localhost:3000`.
   - Allow public reads only for published site media (or use a public CDN origin); keep credentials private and never put them in browser code.
4. Install dependencies, apply the schema, and create the first administrator:

   ```sh
   npm install
   npm run db:migrate
   npm run admin:create-superadmin
   ```

   The setup command prompts for the initial username, email, and password. It requires a 12-character minimum and refuses to create a second initial Super Admin.
5. Run the site:

   ```sh
   npm start
   ```

   Open `http://localhost:3000` for the public site and `http://localhost:3000/admin` for the admin panel.

Migrations are explicit; the server does not silently alter the database at startup. Back up PostgreSQL and object storage before production migrations or deletions.

## Roles enforced by the API

| Capability | Super Admin | Admin | Moderator |
|---|---:|---:|---:|
| Dashboard | Full | Full | Own content |
| Create/edit articles | All | All | Own drafts |
| Publish/unpublish/delete articles | Yes | Yes | No |
| Create/edit videos | All | All | Own drafts |
| Publish/unpublish/delete videos | Yes | Yes | No |
| Categories, homepage sections, site settings | Yes | No | No |
| View users / create accounts | Yes | Yes (Moderator only) | No |
| Change account details, roles, status, passwords | Yes | No | No |

Authorization is checked on every protected API request. Sessions are opaque, signed, stored hashed in PostgreSQL, expire after eight hours, and are invalidated immediately when an account is suspended or its role changes. Mutating API requests require a same-origin `Origin` and CSRF token. Passwords are bcrypt-hashed, login attempts are rate-limited, and the last active Super Admin cannot be suspended or demoted.

Moderators may create content and work on their own drafts; publication and management of other content remain with Admins and Super Admins. The browser hides unavailable controls, but the API also rejects unauthorized requests.

## Operations and production notes

- Set `NODE_ENV=production`, `SESSION_SECRET` to a unique random value, and `MEDIA_PUBLIC_BASE_URL` plus storage credentials. Production startup fails if required secrets/storage settings are missing.
- Set `DATABASE_SSL=true` when the PostgreSQL provider requires TLS. `TRUST_PROXY=1` is only for a deployment behind a trusted single reverse proxy.
- Keep the API and frontend on the same origin; cross-origin API access is intentionally not enabled.
- Configure the object storage CORS policy for direct browser POSTs. Uploads use short-lived signed POST policies with file-size/type limits; the server verifies the completed object before it can be attached to content.
- Supported uploaded image types are JPEG, PNG, WebP, and AVIF. Video entries require an HTTPS YouTube video link; the public video section loads the YouTube thumbnail and opens an embedded player when visitors press play.
- `/healthz` checks database connectivity. The server serves only the public website/admin files and does not expose `.env`, migrations, scripts, or dependencies.
- Published videos appear in the public “ভিডিও পডকাস্ট” category. Published articles appear in the latest/category feeds and article detail pages. Homepage sections and category display/order settings, plus site contact/social settings, are read from persisted records.
- Super Admins can independently reorder homepage categories and navbar categories from Admin → Categories, and select each category's homepage layout. Layout choices include a featured story with headlines, a large-image headlines layout, an image grid, and headlines only.
- “ভিডিও পডকাস্ট” is a video-only category: it shows published playable videos, not articles. New articles cannot be assigned to it; existing legacy article assignments are hidden from public news feeds.
- Admins can update the public Facebook, YouTube, and Instagram destinations from Site settings; blank social URLs hide the corresponding icons. Public-site search matches published article titles, headlines, and summaries.

## Branch workflow

This application is deployed as one Node.js service, so each branch contains the complete working project. Use the branches to group changes by area, then open a pull request into `main` to integrate them.

| Branch | Put changes to these files here |
|---|---|
| `frontend` | `index.html`, `article.html`, `admin.html`, `styles.css`, `admin.css`, `app.js`, `article.js`, `admin.js`, `content.js`, and public image/assets |
| `backend` | `server/` and `scripts/` |
| `database` | `migrations/` and database-specific changes in `server/db.js` |

Create and publish a branch from the latest `main`:

```sh
git switch main
git pull origin main
git switch -c frontend
# Make and commit only frontend changes
git add index.html article.html admin.html styles.css admin.css app.js article.js admin.js content.js
git commit -m "Describe frontend change"
git push -u origin frontend
```

Replace `frontend` with `backend` or `database` and stage the corresponding files from the table. For later work on an existing branch, use `git switch <branch>` instead of `git switch -c <branch>`, then pull and push that branch. Keep `.env` local; commit `.env.example` only when changing the documented configuration template. Open a pull request from the work branch into `main` when the change is ready.

## Checks

```sh
npm run check
```

The repository does not include production credentials or a database/object-storage service. Run migrations and perform end-to-end account/content checks against the PostgreSQL and bucket configured for your deployment before opening the panel to staff.