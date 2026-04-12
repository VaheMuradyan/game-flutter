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
- **XP/League progression** — XP awards on battle end (+50 win, -20 loss). Level = `(xp/100)+1`. League tiers: Bronze (<11), Silver (11-30), Gold (31-60), Diamond (61-99), Legend (100+).
- **Matchmaking (likes/matches)** — Tinder-style mutual-like system. 20 free daily swipes for non-premium users. Mutual likes auto-create a `matches` + `chats` row.

**Database tables:** users, likes, matches, chats, messages, battles. No migration files — schema is managed externally.

## API Routes

All REST endpoints under `/api`. Public: `/api/auth/register`, `/api/auth/login`. Everything else requires `Authorization: Bearer <jwt>`. WebSocket at `/ws/battle` (no auth middleware). Static file serving at `/uploads`.

## Valid Character Classes

Warrior, Mage, Archer, Rogue, Healer (validated in onboarding handler).
