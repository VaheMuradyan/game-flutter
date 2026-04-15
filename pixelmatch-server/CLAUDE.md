# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Run the server (requires PostgreSQL running with pixelmatch DB)
go run main.go

# Build
go build -o pixelmatch-server .

# No tests exist yet. Standard Go test command:
go test ./...
```

Configuration is via environment variables (see `config/config.go` for keys and defaults). Default PostgreSQL credentials: user=pixelmatch, db=pixelmatch, port=5432. Server defaults to port 8080.

## Architecture

This is the Go backend for PixelMatch, a gamified social/battle mobile app with a Flutter client in `pixel_match/`. The server uses **Gin** for HTTP routing, **lib/pq** for PostgreSQL, **gorilla/websocket** for real-time battles, and **golang-jwt** for auth.

**Key architectural patterns:**

- **No ORM** — all database access is raw SQL via `database/sql`, using the global `database.DB` connection pool. Every handler writes its own queries inline.
- **Auth flow** — JWT tokens with `uid` claim. `middleware.AuthRequired` extracts the UID into `c.Set("uid", ...)`, and handlers retrieve it with `c.GetString("uid")`.
- **WebSocket battle system** (`websocket/battle_ws.go`) — in-memory matchmaking queue and battle rooms. Auth is done via message payload (no middleware). A background goroutine ticks every second to check battle timeouts. Battle results are saved async via goroutine.
- **XP/League progression** — XP awards on battle end (+75 win, -10 loss; constants in `config/game_constants.go`). Level = `(xp/100)+1` (currently hardcoded in `websocket/battle_ws.go` ~line 168 — should move to `LevelForXP()`). League tiers via `config.LeagueForLevel()`: Bronze (1-5), Silver (6-12), Gold (13-22), Diamond (23-40), Legend (41+).
- **Battle constants** — `StartingTowerHealth=1200`, `BattleDurationSeconds=150`, `TroopBaseDamage=50`, `SpellDamage=80` (all in `config/game_constants.go`). Canonical source: `design_reference/balance_sheet.md`.
- **Matchmaking (likes/matches)** — Tinder-style mutual-like system. `DailyFreeSwipes=25` for non-premium users, enforced in `handlers/matchmaking.go` via a `CURRENT_DATE` count (refill is implicit/timezone-dependent). Mutual likes auto-create a `matches` + `chats` row.

**Database tables:** users, likes, matches, chats, messages, battles. No migration files — schema is managed externally.

## API Routes

All REST endpoints under `/api`. Public: `/api/auth/register`, `/api/auth/login`. Everything else requires `Authorization: Bearer <jwt>`. WebSocket at `/ws/battle` (no auth middleware). Static file serving at `/uploads`.

## Valid Character Classes

Warrior, Mage, Archer, Rogue, Healer (validated in onboarding handler).
