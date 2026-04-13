# PixelMatch — Improvement Roadmap

## Context
Phases 1–15 ship the core game. This roadmap covers the next wave: polish, feel, balance, and ops tooling. Each item below is a standalone spec file that can be picked up independently. Items are ordered by expected player-impact, not dependency.

## Tooling Notes
- **Design work** uses Google Stitch MCP (mockups) → translated manually to Flutter widgets/Flame.
- **Admin panel only** uses Magic MCP (21st.dev) since it emits React/Tailwind — not usable for the Flutter client.
- Specialized agents to invoke: `design-ui-designer`, `game-designer`, `game-audio-engineer`, `engineering-mobile-app-builder`, `engineering-frontend-developer`, `testing-performance-benchmarker`.

## Tracks

| # | Track | File | Primary Agent | MCP |
|---|---|---|---|---|
| 1 | Battle HUD & feedback polish | [improvement_battle_ux.md](improvement_battle_ux.md) | design-ui-designer | Stitch |
| 2 | Game balance & economy pass | [improvement_game_balance.md](improvement_game_balance.md) | game-designer | — |
| 3 | Adaptive battle audio | [improvement_battle_audio.md](improvement_battle_audio.md) | game-audio-engineer | — |
| 4 | Swipe / match screen refresh | [improvement_match_ui.md](improvement_match_ui.md) | design-ui-designer | Stitch |
| 5 | Web admin panel | [improvement_admin_panel.md](improvement_admin_panel.md) | engineering-frontend-developer | Magic |
| 6 | Brand identity & logo | [improvement_branding.md](improvement_branding.md) | design-ui-designer | logo_search |
| 7 | Mobile performance audit | [improvement_mobile_perf.md](improvement_mobile_perf.md) | engineering-mobile-app-builder | — |

## Shared Constraints
- Any change to XP, league thresholds, battle duration, or troop stats must update **both** `pixel_match/lib/config/constants.dart` **and** `pixelmatch-server/websocket/battle_ws.go` (see CLAUDE.md §"How the Two Projects Connect").
- No Firebase. No schema migration files — DB changes are applied manually to the `pixelmatch` Postgres DB.
- WebSocket protocol messages (`join_queue`, `battle_start`, `deploy_troop`, `tower_hit`, `battle_end`, `leave_queue`) are a stable contract; extend, don't break.
