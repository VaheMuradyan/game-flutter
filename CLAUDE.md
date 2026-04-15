# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This is a monorepo for **PixelMatch**, a gamified dating/battle mobile app. It contains two projects:

- `pixel_match/` — Flutter client (Dart, Flame game engine, Provider state management)
- `pixelmatch-server/` — Go backend (Gin, PostgreSQL, gorilla/websocket)

Each sub-project has its own `CLAUDE.md` with project-specific architecture details and commands.

## Quick Start

```bash
# --- Backend (requires PostgreSQL with pixelmatch DB) ---
cd pixelmatch-server
go run main.go                    # starts on :8080

# --- Flutter client ---
cd pixel_match
flutter pub get
flutter run -d chrome             # web dev (easiest)
flutter run -d linux              # desktop dev
```

Before running the Flutter client, set `apiBaseUrl` and `wsBaseUrl` in `pixel_match/lib/config/constants.dart` to point at the running server.

## Common Commands

```bash
# Go server
cd pixelmatch-server
go build -o pixelmatch-server .   # build binary
go test ./...                     # run tests (none exist yet)

# Flutter client
cd pixel_match
flutter analyze                   # lint/static analysis
flutter test                      # run all tests
flutter test test/widget_test.dart  # single test file
```

## How the Two Projects Connect

1. **REST API** — Flutter's `ApiClient` (`pixel_match/lib/config/api_client.dart`) makes HTTP calls to `pixelmatch-server/` endpoints under `/api`. JWT auth token stored in `SharedPreferences`, auto-attached to requests.

2. **WebSocket** — `WebSocketService` (`pixel_match/lib/services/websocket_service.dart`) connects to `/ws/battle` on the Go server (`pixelmatch-server/websocket/battle_ws.go`). Auth is done via message payload, not HTTP middleware. Messages are JSON with a `type` field: `join_queue`, `battle_start`, `deploy_troop`, `tower_hit`, `battle_end`, `leave_queue`.

3. **Shared constants** — XP values, league thresholds, battle duration, character classes, and swipe limits are mirrored across three places that must stay in sync (any drift is a bug). Canonical source: `design_reference/balance_sheet.md`.
   - Flutter: `pixel_match/lib/config/constants.dart`
   - Go: `pixelmatch-server/config/game_constants.go` (XPPerWin=75, XPPerLoss=-10, StartingTowerHealth=1200, BattleDurationSeconds=150, DailyFreeSwipes=25, `LeagueForLevel()`)
   - Note: mana, troop cost, troop speed, and spell cost currently live only in the Flutter constants and have no server mirror yet.

## Configuration

Go server uses environment variables with defaults (see `pixelmatch-server/config/config.go`):
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` — PostgreSQL connection
- `JWT_SECRET` — signing key for auth tokens
- `SERVER_PORT` — defaults to 8080
- `UPLOAD_DIR` — photo upload directory, defaults to `./uploads`

## Database

PostgreSQL database `pixelmatch`. Tables: `users`, `likes`, `matches`, `chats`, `messages`, `battles`. No migration files — schema is managed externally. All database access is raw SQL via `database/sql` using the global `database.DB` pool (no ORM).

## Phase Documents

The `phase*.md` files at the repo root are implementation specification documents describing the feature roadmap. Reference these when implementing new features.
