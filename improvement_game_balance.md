# Improvement 2 — Game Balance & Economy Pass

## Context
Core numbers (XP ±50/−20, tower HP 1000, match duration 180s, league thresholds, character classes, swipe limits) were set early for phase implementation and have not been tuned against real playtests. Before onboarding real users, these need a structured balance pass so the progression curve feels rewarding and matches don't end in stalemates or blowouts.

## Goal
A documented, tunable economy where: average match ends decisively, league climbs feel earned over ~10–15 matches, and swipe limits create FOMO without hard-walling free players.

## Scope
### In
- Audit of all tunable constants with current values and proposed ranges
- XP curve shape (linear vs. soft-exponential) and league thresholds
- Tower HP × match duration relationship (aim for 70–80% of matches ending before timeout)
- Troop cost / damage / cooldown table
- Daily swipe limit + refill cadence
- A single source-of-truth "balance sheet" doc

### Out
- New troops, new leagues, new game modes
- UI changes
- Matchmaking algorithm

## Files to Touch
- `pixel_match/lib/config/constants.dart` — tunable values
- `pixelmatch-server/websocket/battle_ws.go` — server-authoritative tower HP, duration, XP
- `pixelmatch-server/handlers/` — swipe limit enforcement, league transitions
- **New:** `design_reference/balance_sheet.md` — the canonical table

## Approach
1. Invoke `game-designer` agent with the current constants as input. Ask for: curve analysis, target match-length distribution, proposed new values with rationale.
2. Produce `balance_sheet.md` as the single source of truth (Flutter + Go constants must mirror it).
3. Apply changes to both codebases in one PR. Any mismatch between client and server is a bug.
4. Add a comment above each tunable pointing to the balance sheet.

## Verification
- Play 10 matches against self/bot and record: match length, winner margin, XP earned. Compare to targets.
- Confirm client and server constants match via `grep` on tower HP / duration / XP values.
- `go build ./...` and `flutter analyze` clean.
