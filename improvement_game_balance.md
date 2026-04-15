# Improvement 2 — Game Balance & Economy Pass

## Context
A partial tuning pass has already landed. The current authoritative values live in
`pixelmatch-server/config/game_constants.go`:

- `XPPerWin = 75`, `XPPerLoss = -10`, `MinXP = 0`
- `StartingTowerHealth = 1200`, `BattleDurationSeconds = 150`
- `TroopBaseDamage = 50`, `SpellDamage = 80`
- `DailyFreeSwipes = 25`, `PremiumSwipeLimit = 999999`
- `LeagueForLevel(level)` → Bronze (<6), Silver (6–12), Gold (13–22), Diamond (23–40), Legend (41+)

The Flutter client (`pixel_match/lib/config/constants.dart`) mirrors the XP, tower HP,
duration, and league ranges, but it also carries a set of **client-only** combat-economy
constants that have no server counterpart:

- `manaRegenPerSecond = 1.0`, `maxMana = 10`, `startingMana = 5.0`
- `troopCost = 3.0`, `troopSpeed = 60.0`
- `spellCost = 5.0`

These are trust-the-client values today and are therefore exploitable — the server accepts
`tower_hit` damage numbers from the client without bounds-checking them against mana or
cost. Any real balance pass has to close this gap before the numbers mean anything.

In addition, a prior review found two correctness bugs in `websocket/battle_ws.go`:

1. `checkTimer()` at lines ~119–131: on a timeout tie (`TowerHealth[1] == TowerHealth[0]`)
   the winner silently defaults to `Players[0]`. No tie-breaker rule is documented.
2. `awardXP()` at line 168 hardcodes `newLevel = (newXP / 100) + 1`, bypassing
   `config.LeagueForLevel` and leaving the level curve stranded outside `game_constants.go`.
   If we ever change the curve shape, the league mapping and the level math will drift.

The canonical balance sheet at `design_reference/balance_sheet.md` **already exists** and
is referenced from both `game_constants.go` and `constants.dart`. It is the intended source
of truth — not a new file.

Swipe resets are implicit: `handlers/matchmaking.go:51` counts `likes` where
`created_at >= CURRENT_DATE`, so "refill" is a wall-clock midnight rollover in the server's
local timezone. There is no explicit refill cadence documented or tested.

## Goal
Preserve the current design spirit — decisive matches, climbs that feel earned, swipe
limits that create FOMO without hard-walling free players — and make it **measurable**:

| Target                                   | Threshold                 |
| ---------------------------------------- | ------------------------- |
| Matches ending on timeout vs. tower kill | timeout rate **< 20 %**   |
| Closeness of decisive matches            | median margin **< 40 %** of `StartingTowerHealth` |
| Time-to-Silver for a new account         | **10–15 matches**         |
| Client/server constant drift             | **0** (enforced by grep)  |

These are the pass/fail gates for the balance pass.

## Scope

### In
- Audit of all tunable constants across the three mirrors (`game_constants.go`,
  `constants.dart`, `balance_sheet.md`) and a drift report
- Telemetry / event logging for: match length, winner, both tower HPs at end, XP delta,
  player level at match start (needed before any numbers can be validated)
- Explicit tie-breaker rule for `checkTimer()` (not `Players[0]` by accident)
- Anti-snowball / comeback lever (e.g., mana-regen bonus or damage multiplier for the
  losing tower once it drops below a threshold)
- Mana / troop-cost / spell-cost mirror from the client into `game_constants.go`, plus
  server-side validation of client-reported damage against those constants
- Swipe refill cadence documented and tested (timezone behaviour of
  `CURRENT_DATE` in `matchmaking.go`)
- Extraction of the level formula into `config.LevelForXP()` in `game_constants.go`, and
  replacement of the hardcoded expression in `battle_ws.go`
- Tower-HP × duration × damage re-tuning against target distributions
- XP curve shape (keep linear vs. switch to soft-exponential per league)

### Out
- New troops, new spells, new leagues, new game modes
- UI / HUD changes
- Matchmaking algorithm changes (FIFO pairing stays — see **Risks**)

## Files to Touch
- `pixelmatch-server/config/game_constants.go` — source of truth for all tunables; add
  `LevelForXP()`, mana/troop/spell constants, tie-breaker constant
- `pixel_match/lib/config/constants.dart` — align mirrors, delete any stale comments
- `pixelmatch-server/websocket/battle_ws.go` — fix tie-breaker at ~L119–131, replace
  hardcoded level formula at ~L168 with `config.LevelForXP(newXP)`, add server-side
  damage validation in the `tower_hit` handler (~L293–303)
- `pixelmatch-server/handlers/matchmaking.go` — document / test swipe refill cadence at
  ~L35–54; if we switch to rolling 24 h, change the `CURRENT_DATE` query here
- `pixelmatch-server/handlers/premium.go` — **verified**: holds only premium status /
  activation, no swipe-count logic. Touch only if the refill cadence change needs a
  premium-side hook (likely not)
- `design_reference/balance_sheet.md` — **already exists**; update, do not create

## Approach

### Step 0 — Audit current state (new)
1. `grep -rn "xpPerWin\|XPPerWin\|tower.*ealth\|battleDuration\|BattleDuration" pixel_match pixelmatch-server`
2. Diff the three mirrors (balance sheet, Go constants, Dart constants) and list every
   drift point in a scratch file. Do not change anything until the drift list is empty or
   explained.
3. Pull the last 30 days of `battles` rows from Postgres (if any exist) as a first
   empirical data point. If the table is empty, flag that telemetry **must** land before
   tuning can begin.

### Step 1 — Telemetry first
Add structured event logging in `saveBattleResult()` and in the `tower_hit` / timeout paths
so every match emits: `{duration, end_reason (kill|timeout|disconnect), margin_hp,
winner_level, loser_level}`. No tuning is done without this data.

### Step 2 — Invoke the `game-designer` agent
Feed it the audited current constants, the drift list, the telemetry schema, and the
target table from **Goal**. Ask for: curve analysis, anti-snowball lever proposal, revised
values with explicit rationale per variable.

### Step 2.5 — Paper Monte Carlo (new)
Before touching code, model `mana × troopCost × HP × duration` on paper:

- Max sustainable DPS = `(manaRegenPerSecond × BattleDurationSeconds / troopCost) ×
  TroopBaseDamage`
- Theoretical max damage per match (both players full-send) vs. `StartingTowerHealth × 2`
- Identify the theoretical min/max match length and the expected timeout rate at current
  numbers. If the paper model disagrees with the **Goal** thresholds, adjust before
  writing code.

### Step 3 — Code changes
1. **Bug fix**: replace the tie-breaker at `battle_ws.go:119–131` with an explicit rule
   (sudden-death damage tick, higher total-damage-dealt, or coin-flip + event log).
2. **Refactor**: add `LevelForXP(xp int) int` to `game_constants.go` and call it from
   `awardXP()` at `battle_ws.go:168`. Delete the hardcoded `(newXP/100)+1`.
3. **Mirror**: move `manaRegenPerSecond`, `maxMana`, `startingMana`, `troopCost`,
   `spellCost`, `troopSpeed` into `game_constants.go`. Keep the Dart copies as display
   mirrors with a comment pointing to the Go source.
4. **Server-side validation**: in the `tower_hit` case of `HandleBattleWS` (~L293–303),
   cap `damage` at `config.TroopBaseDamage` (or whatever the canonical per-hit cap is) and
   log + drop any over-cap message.
5. **Swipe refill cadence**: decide (a) keep midnight server-local via `CURRENT_DATE`, or
   (b) rolling 24 h via `created_at >= NOW() - INTERVAL '24 hours'`. Document the choice
   in `balance_sheet.md §6` and update the query at `matchmaking.go:35`.
6. **Tuning**: apply the new values from Step 2/2.5 to `balance_sheet.md` first, then
   propagate to `game_constants.go` and `constants.dart` in a single commit.

### Step 4 — Keep the sheet canonical
Every tunable in both code files must carry a `// balance_sheet.md §N` comment pointing at
its section. Any new constant added without that comment fails review.

## Verification
- **30+ logged matches** (self + bot + teammate playtest) with the telemetry from Step 1.
- **Pass/fail gates** — computed from the telemetry, not vibes:
  - timeout rate **< 20 %**
  - median margin on decisive matches **< 40 %** of `StartingTowerHealth` (i.e., < 480 HP)
  - time-to-Silver on a fresh account **in 10–15 matches**
- **Tie-breaker regression test** — unit test in `websocket/` that constructs a
  `BattleRoom` with equal HP and asserts the documented tie-breaker fires (not a silent
  `Players[0]` default).
- **Drift grep** — a single script or doc snippet that greps XP, tower HP, duration, mana,
  troop cost, spell cost across `balance_sheet.md`, `game_constants.go`, `constants.dart`
  and exits non-zero on mismatch. Run it in CI if possible.
- **Build checks** — `go build ./...` and `flutter analyze` clean, `go test ./...` passes
  (including the new tie-breaker test).

## Risks
- **FIFO matchmaking**: `battle_ws.go:239–276` pairs whichever two players happen to be
  waiting in the queue, regardless of level or league. Any balance data collected during
  playtests is only meaningful if both players are in a narrow level band. If the
  playtest group spans e.g. Bronze 2 and Gold 3, timeout and margin numbers will look
  bimodal and the **Goal** thresholds will be invalid. Flag this as an **assumption** in
  every playtest report, and consider a throwaway level-band filter for the balance pass
  window even though "matchmaking changes" are out of scope for the pass itself.
- **Client-authoritative combat**: until mana, `troopCost`, and `spellCost` are mirrored
  to `game_constants.go` **and** `tower_hit` damage is validated server-side, a modified
  client can send arbitrary damage. Every balance number we ship is exploitable until
  that mirror lands. Do Step 3.3 and 3.4 in the same PR as the tuning change or the pass
  is theatre.
- **Level-formula drift**: the hardcoded `(newXP/100)+1` at `battle_ws.go:168` has
  already silently diverged from `LeagueForLevel`. Until Step 3.2 lands, any curve tweak
  in `balance_sheet.md` is a no-op on the server.
- **Timezone of `CURRENT_DATE`**: swipe rollover happens at whatever the Postgres
  server's local midnight is. A user travelling across timezones will see rollovers at
  unexpected times. Acceptable if documented; a latent support ticket otherwise.
