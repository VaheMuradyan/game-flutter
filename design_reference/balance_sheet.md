# PixelMatch — Balance Sheet

Canonical source of truth for all tunable game constants. **Flutter
(`pixel_match/lib/config/constants.dart`, `pixel_match/lib/game/pixel_match_game.dart`)
and Go (`pixelmatch-server/config/game_constants.go`, `pixelmatch-server/websocket/battle_ws.go`)
must mirror these exactly.** Any divergence is a bug.

Last tuned: 2026-04-14.

---

## 1. XP & Progression

| Constant       | Old   | New  | Rationale                                                               |
|----------------|-------|------|-------------------------------------------------------------------------|
| `xpPerWin`     | +50   | +75  | Faster progression; league climb feels earned in ~10–15 matches per tier |
| `xpPerLoss`    | −20   | −10  | Losing a match shouldn't feel like being sent backwards                  |
| Level formula  | `xp/100 + 1` | `xp/100 + 1` | Kept linear for predictability. League curve is the lever       |
| MinXP          | 0     | 0    | Floor                                                                   |

**Net XP / match (50% winrate):** `(75 − 10) / 2 = +32.5`
**Net XP / match (55% winrate):** `(75 · 0.55 + (−10) · 0.45) = +36.75`

## 2. League Thresholds (by level)

| League  | Old levels | New levels | Matches to enter (at 55% wr, ~37 xp/match) |
|---------|-----------|-----------|---------------------------------------------|
| Bronze  | 1–10      | 1–5       | 0                                           |
| Silver  | 11–30     | 6–12      | ~14 matches (500 xp)                        |
| Gold    | 13–22     | 13–22     | ~33 matches (1200 xp)                       |
| Diamond | 61–99     | 23–40     | ~60 matches (2200 xp)                       |
| Legend  | 100+      | 41+       | ~109 matches (4000 xp)                      |

**Target:** each tier climb feels meaningful. Bronze→Silver in a first session; Gold within a week of daily play; Legend is a grind.

## 3. Battle Duration & Tower HP

| Constant                | Old  | New  | Rationale |
|-------------------------|------|------|-----------|
| `battleDurationSeconds` | 180  | 150  | Shorter matches → more sessions per play burst, higher retention |
| `startingTowerHealth`   | 1000 | 1200 | Slight HP bump so the shorter timer doesn't make burst-rush trivial |

**Math check (one-sided max DPS):**
- Troop cost 3 mana, damage 50 → 16.7 dmg/s peak once mana is saturated
- Over 150s: ~2500 theoretical dmg vs 1200 HP
- Target: 70–80% of matches end decisively before timeout. Tower falls by ~75s of optimal play; casual play lands around the 120–140s mark.

## 4. Mana & Combat Economy

| Constant           | Old | New | Rationale |
|--------------------|-----|-----|-----------|
| `maxMana`          | 10  | 10  | Keep |
| `manaRegenPerSecond` | 1.0 | 1.0 | Keep |
| `startingMana`     | 5   | 5   | Keep |
| `troopCost`        | 3   | 3   | Keep — baseline |
| `troopBaseDamage`  | 50  | 50  | Keep |
| `troopSpeed`       | 60  | 60  | Keep |
| `spellCost`        | 5   | 5   | Keep |
| `spellDamage`      | 100 | 80  | Nerf — was 20 dmg/mana vs troop 16.7; spell was strictly dominant |

**Damage per mana after change:**
- Troop: 16.7 dmg/mana
- Spell: 16.0 dmg/mana — now slightly behind troops, rewarded by instant-delivery rather than raw efficiency.

## 5. Troop Cost / Damage / Cooldown (future per-class table)

Currently all classes share the same stats. This table is the target shape for
Phase 3 class differentiation. **Not wired up yet** — implementation is out of
scope for this balance pass.

| Class   | Cost | Damage | Speed | Niche            |
|---------|------|--------|-------|-------------------|
| Warrior | 3    | 50     | 60    | Baseline          |
| Mage    | 4    | 75     | 55    | Burst             |
| Archer  | 3    | 40     | 70    | Skirmisher        |
| Rogue   | 2    | 30     | 80    | Chip damage       |
| Healer  | 4    | 20     | 55    | Support (unique)  |

## 6. Swipe Economy

| Constant          | Old | New | Rationale |
|-------------------|-----|-----|-----------|
| `dailyFreeSwipes` | 20  | 25  | Slight lift — 20 was cutting off engaged free users; 25 leaves room to discover matches without hard-walling |
| Refill cadence    | midnight (server) | midnight (server) | Keep — simple, predictable |
| `premiumSwipeLimit` | 999999 | 999999 | Effectively unlimited |

**FOMO target:** 25 is roughly 2 full browse sessions/day. Power users still
hit the wall by late evening, which is the signal we want for premium conversion.

---

## Verification checklist

- [ ] Flutter `constants.dart` values match this sheet
- [ ] Flutter `pixel_match_game.dart` spell damage matches
- [ ] Go `game_constants.go` values match this sheet
- [ ] Go `battle_ws.go` uses constants from `game_constants.go` (no magic numbers)
- [ ] `go test ./config/...` passes (league-threshold test updated)
- [ ] `flutter analyze` clean
- [ ] 10 playtests recorded with match length / winner margin / xp earned
