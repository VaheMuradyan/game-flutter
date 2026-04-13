# Improvement 7 — Mobile Performance Audit

## Context
Battles run Flame rendering + an always-on WebSocket + frequent state updates. None of it has been profiled under realistic conditions (mid-range Android, flaky network, 180-second session). Before a wider release, we need a measured baseline and a shortlist of fixes — otherwise player-reported "it's laggy" has no actionable owner.

## Goal
A measured performance baseline on a real mid-range Android device, a ranked list of regressions, and fixes landed for anything that drops below 55 FPS during a battle.

## Scope
### In
- Frame-time profile of a full battle on a real device
- WebSocket reconnect behavior under simulated network drop
- Memory profile over 10 consecutive matches (leak check)
- Battery drain measurement for a 10-minute session
- Fixes for any finding where cost < 1 day and FPS impact > 5

### Out
- iOS profiling (separate track if needed)
- Backend performance
- CI performance gates

## Files to Touch
- Depends on findings. Likely candidates:
  - `pixel_match/lib/game/` — Flame component rebuild hotspots
  - `pixel_match/lib/services/websocket_service.dart` — reconnect logic
  - Any widget rebuilding on every `notifyListeners()` from Provider

## Approach
1. Invoke `engineering-mobile-app-builder` + `testing-performance-benchmarker` to run:
   - `flutter run --profile` on a real device
   - Flutter DevTools frame chart during a battle
   - DevTools memory tab over 10 matches
2. Produce a findings doc at `design_reference/perf_baseline.md` with: device model, Android version, observed FPS distribution, memory growth per match, battery delta.
3. Fix each finding where effort < 1 day and impact > 5 FPS. Anything bigger becomes its own ticket.
4. Re-measure after fixes — keep the before/after in the findings doc.

## Verification
- Baseline and post-fix numbers recorded in `perf_baseline.md`.
- Average in-battle FPS ≥ 55 on the test device.
- Memory does not grow by more than 20 MB across 10 matches (no obvious leak).
- WebSocket auto-reconnects within 3 seconds after a simulated network drop mid-battle.
