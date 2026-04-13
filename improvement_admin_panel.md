# Improvement 5 — Web Admin Panel

## Context
Operations today have no UI — moderation, user lookups, battle analytics, and content review all require direct Postgres access. This blocks anyone non-technical from helping run the service, and is the first legitimate use of Magic MCP (21st.dev emits React/Tailwind, which would be wrong for the Flutter client but is exactly right for an admin web app).

## Goal
A standalone React + Tailwind dashboard that talks to the existing Go API, letting a trusted operator: list users, review reported profiles, view battle history, and see aggregate league / match-length stats.

## Scope
### In
- New repo subdirectory `pixelmatch-admin/` (React + Vite + Tailwind + TanStack Query)
- Login screen reusing the existing `/api/auth/login` endpoint
- Role-guarded: only users with `is_admin = true` can sign in (add column to `users` table — one-time manual `ALTER TABLE`)
- Pages: Users list, User detail, Reports queue, Battles list, Stats dashboard
- Read-only v1 — no destructive actions yet

### Out
- Writes / bans / refunds (v2)
- Realtime updates
- Hosting / CI — local `npm run dev` only for v1

## Files to Touch
- **New:** `pixelmatch-admin/` project (Vite scaffold)
- `pixelmatch-server/handlers/admin.go` — **new**, aggregate stats endpoints
- `pixelmatch-server/middleware/` — admin-only middleware checking `is_admin`
- `pixelmatch-server/main.go` — mount `/api/admin/*` routes
- Database: `ALTER TABLE users ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT false;`

## Approach
1. Scaffold Vite + React + Tailwind in `pixelmatch-admin/`.
2. Invoke `engineering-frontend-developer` to plan the component tree.
3. Use **Magic MCP** (`21st_magic_component_builder`) to generate: data table, stat card, nav shell, detail drawer. Refine with `21st_magic_component_refiner`.
4. Add the `is_admin` column manually and flip it to true for one test user.
5. Build `/api/admin/stats`, `/api/admin/users`, `/api/admin/battles` endpoints — read-only SQL aggregates over existing tables.
6. Wire TanStack Query against `VITE_API_BASE_URL`.

## Verification
- Start Go server, start admin panel (`npm run dev`), log in as admin user — non-admin login rejected.
- Users page shows real users from the `pixelmatch` DB.
- Stats page shows counts (total users, matches today, battles today, avg battle duration).
- `go build ./...` and admin panel builds clean with `npm run build`.
