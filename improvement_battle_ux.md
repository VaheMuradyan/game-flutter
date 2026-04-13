# Improvement 1 — Battle HUD & Feedback Polish

## Context
The battle screen is the game's primary loop. Right now the HUD (tower health, troop deploy cards, timer, victory/defeat screens) is functional but flat. Players judge a competitive mobile game in the first 10 seconds of a match — this track makes the battle screen feel reactive, readable, and worth returning to.

## Goal
Every player action produces clear visual feedback. The HUD communicates match state at a glance. Victory/defeat screens feel earned.

## Scope
### In
- Tower health bars — animated drain, damage flash, low-HP pulse
- Troop deploy card dock — cost, cooldown, drag-to-deploy affordance
- Match timer — urgency styling in final 30s
- Damage numbers / hit sparks on tower impact
- Victory & defeat screens — XP gained, league progress ring, rematch CTA
- Haptics on deploy, tower hit, match end

### Out
- Gameplay rule changes (see improvement_game_balance.md)
- Audio (see improvement_battle_audio.md)
- New troop types

## Files to Touch
- `pixel_match/lib/screens/battle_screen.dart` — HUD layout
- `pixel_match/lib/game/` — Flame components for towers, troops, effects
- `pixel_match/lib/widgets/` — add `tower_health_bar.dart`, `troop_card.dart`, `battle_result_screen.dart`
- `pixel_match/lib/config/constants.dart` — read-only, reference for tower max HP / match duration

## Approach
1. Invoke `design-ui-designer` with Google Stitch to produce mockups for: battle HUD, troop dock, victory screen, defeat screen. Save mockups under `design_reference/battle/`.
2. Translate mockups to Flutter widgets. Reuse existing theme tokens from `constants.dart` / any theme file — do not hardcode colors.
3. Add Flame particle effects for tower hits using Flame's built-in `ParticleSystemComponent`.
4. Wire `HapticFeedback.lightImpact()` / `mediumImpact()` at the deploy + hit callsites.

## Verification
- Run `flutter run -d chrome` and play a full match end-to-end.
- Confirm: tower HP animates smoothly, low-HP pulses, timer turns red <30s, victory screen shows correct XP delta from server `battle_end` payload.
- `flutter analyze` clean.
- Manual regression: swipe/match flow unaffected.
