# PixelMatch Stress Tests

Pure-Go stress tests for the PixelMatch backend. No external tools (k6, vegeta, etc.) — everything is `net/http` + `gorilla/websocket` driven from goroutines so the tests live inside the server's module and can be run with `go run`.

## Layout

```
stress/
  cmd/
    rest/    # REST-only: auth + home-screen-ish reads under concurrency
    ws/      # WebSocket-only: N clients battle via /ws/battle
    mixed/   # Browsers + battlers concurrently hitting REST + WS
  internal/
    metrics/     # latency recorder, p50/p95/p99 + req/s reporter
    httpclient/  # thin REST wrapper (register/login/onboarding/reads/likes)
    wsclient/    # battle WS client (join_queue/deploy/tower_hit/battle_end)
    fixtures/    # registers + onboards a pool of stress users
```

## Prereqs

Before running any scenario you need:

1. A running server: `cd pixelmatch-server && go run main.go` (listens on `:8080`).
2. A reachable PostgreSQL with the `pixelmatch` schema (same as normal dev).
3. The `/api/auth/register` and `/api/auth/login` routes have a rate limiter of **10 req/min per IP** (`main.go` passes `middleware.RateLimit(10, 1*time.Minute)`). All scenarios register fresh users at startup, so for anything more than ~10 users you'll either:
   - Run the scenarios against a server with the limit relaxed (edit `main.go` locally; don't commit), or
   - Chunk your runs and wait a minute between them, or
   - Lower `-users` / `-players` below 10.

This suite does **not** modify production server code. If you hit the limit you'll see `register: POST /api/auth/register: 429 ...` in the setup phase and the run will abort early.

## Compiling

```bash
cd pixelmatch-server
go build ./stress/...
```

That builds all three scenario binaries without running them — quickest way to verify code still compiles after changes.

## Running the scenarios

All three accept `-h` for flag docs.

### 1. REST scenario (`cmd/rest`)

Spins up `-users` authenticated users, then drives `-concurrency` workers that each pick a random user per iteration and run a realistic home-screen burst:

- `GET /api/me` (x2)
- `GET /api/users/eligible`
- `GET /api/leaderboard`
- `GET /api/leaderboard/:league`
- `GET /api/likes/today`
- `GET /api/battles/history`
- `GET /api/matches`

```bash
go run ./stress/cmd/rest \
  -base http://localhost:8080 \
  -users 8 \
  -concurrency 50 \
  -duration 30s
```

**Reports**: per-endpoint count, ok / fail, req/s, p50 / p95 / p99 / max latency, and an error-rate line for any endpoint with failures.

Useful for: finding slow queries (e.g. `ORDER BY RANDOM()` in `/users/eligible`), db connection pool sizing, regressions in read paths.

### 2. WebSocket battle scenario (`cmd/ws`)

Dials `-players` WS clients in parallel, each sends `join_queue`, the server pairs them off into battles, then each client fires `deploy_troop` + `tower_hit` on `-hit-interval` until it sees `battle_end` (or its `-max-battle` deadline fires).

```bash
go run ./stress/cmd/ws \
  -base http://localhost:8080 \
  -players 10 \
  -hit-interval 200ms \
  -damage 50 \
  -max-battle 45s
```

**Reports**:

- `ws.connect` — time to open the WS handshake
- `ws.match (join->start)` — matchmaking latency (join_queue sent → battle_start received)
- `ws.tower_hit rtt` — round-trip from sending tower_hit to receiving the server's `damage` broadcast (a proxy for lock contention on `battleMu` / per-room mutex)
- `ws.battle duration` — end-to-end battle time for naturally-ended games
- Peak concurrent WS connections, natural-end vs. deadline-cutoff battle counts, send-error count

Notes:

- Use an **even** `-players` count. The server's matchmaker pairs FIFO, so odd N leaves one client stuck in the queue indefinitely — it'll be reported as "never matched".
- The WS handler does **not** validate the JWT (see finding #1 below). The scenario sends the user's UID in the `join_queue` payload because that's what the server uses.

### 3. Mixed workload (`cmd/mixed`)

The most interesting scenario for contention hunting. Splits the user pool into battlers and browsers running concurrently:

- Battlers loop `connect → join_queue → fight → disconnect → repeat` until the deadline.
- Browsers loop `GET /api/me → (eligible | leaderboard | history)` every `-rest-interval`.

```bash
go run ./stress/cmd/mixed \
  -base http://localhost:8080 \
  -users 20 \
  -battler-fraction 0.4 \
  -duration 60s \
  -hit-interval 300ms \
  -rest-interval 500ms
```

**Reports**: REST latency distributions AND WS match/battle/RTT distributions side by side, plus battle completion counts and peak concurrent WS connections.

Useful for: finding interactions between the WS battle-save goroutine (which does 3 DB writes at `battle_end`: `INSERT battles` + `UPDATE users` twice) and read queries that scan `users` or `battles` at the same time.

## Metrics definitions

- **count** — total operations attempted (ok + fail).
- **ok / fail** — 2xx and WS successful sends vs. everything else.
- **rps** — `count / wall-clock duration`; the wall-clock is the whole scenario run, so setup time slightly lowers this vs. the steady-state peak.
- **p50 / p95 / p99 / max** — quantiles over every sample (exact, not HDR-approximate — see `internal/metrics`).
- **Peak concurrent WS connections** — high-water mark of live connections across the run (atomic counter).

## What to try next

- Run `rest` with `-duration 5m` and watch Go's runtime — allocations show up in `pprof` via `http://localhost:8080/debug/pprof/` if you add the import in a dev-only branch.
- Run `ws` with `-players 200` against a server with relaxed auth limits to find out when matchmaking latency starts fat-tailing.
- Run `mixed` with a smaller `DB_MAX_OPEN_CONNS` to reproduce pool exhaustion.

## Observations while writing these tests

A few things surfaced during code exploration. **Not fixed** — reporting only:

1. **`/ws/battle` does not authenticate.** `websocket.HandleBattleWS` trusts whatever `uid` the client puts in the `join_queue` payload. Any WS client can impersonate any user (awarding or draining their XP, creating fake battle history). Stress tests work around it; production should not.

2. **Damage is client-authoritative.** `tower_hit` takes a client-supplied `damage` int and applies it verbatim (`websocket/battle_ws.go` ~line 296). A malicious client can end any battle in one message by sending `damage: 1200`. The stress tests use 50 to mirror real clients.

3. **Unbounded in-memory battle map.** `battles[room.ID] = room` is set on every match but I didn't find a delete after `endBattle`. The 1s ticker goroutine iterates every ended battle forever. Long-running servers will leak memory proportional to total lifetime matches. The mixed scenario with `-duration 5m` + many battles will make this visible with `runtime.ReadMemStats`.

4. **`awardXP` is a read-modify-write across two DB calls.** `SELECT xp` → compute → `UPDATE users` is not a transaction; two simultaneous battle-ends for the same user (possible with rapid disconnect/reconnect flows) will lose one of the XP updates. The ws and mixed scenarios don't race the same user hard enough to reliably trigger this, but it's there.

5. **Level formula drift.** `battle_ws.go` hardcodes `newLevel := (newXP / 100) + 1` instead of calling a `LevelForXP` helper next to `LeagueForLevel`. The server's own CLAUDE.md already flags this.

6. **`ORDER BY RANDOM()` in `/api/users/eligible`.** Full-table sort on every call. Shows up as a slow endpoint once the `users` table grows; REST scenario makes this obvious even with hundreds of rows.

7. **Auth rate limit blocks these tests.** The 10-req/min-per-IP limit is correct for production but makes stress setup annoying from a single IP. Consider a separate rate-limit config for dev/load-test env (e.g. keyed off `APP_ENV`).
