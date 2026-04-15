# PixelMatch Mobile Performance Baseline

## Audit Method

**This is a static code audit, not a device-measured baseline.** No mid-range Android device was available during this pass, so every "impact" rating below is a code-reading estimate, not a profiler reading. Real numbers still need to be collected — see the *Instrumentation Plan* section — but the hotspots and fix shortlist can be acted on immediately because they are structural issues visible in source.

Scope audited:
- `pixel_match/lib/game/pixel_match_game.dart`
- `pixel_match/lib/game/components/` (`arena.dart`, `tower.dart`, `troop.dart`, `spell.dart`)
- `pixel_match/lib/game/battle_audio.dart`, `class_colors.dart`
- `pixel_match/lib/services/websocket_service.dart`, `audio_service.dart`
- `pixel_match/lib/providers/battle_provider.dart`
- `pixel_match/lib/screens/battle/battle_screen.dart`
- `pixel_match/lib/widgets/troop_card.dart`

FPS impact scale used: **Low** (<2 FPS), **Medium** (2-5 FPS), **High** (5-15 FPS), **Critical** (>15 FPS or visible stutter).

---

## Flame Render Hotspots

Ranked by estimated frame-time cost during an active battle with ~4-8 troops + occasional particle bursts.

| # | File:Line | Issue | FPS Impact | Fix Effort |
|---|-----------|-------|------------|------------|
| F1 | `pixel_match_game.dart:222` | `Paint()..color = const Color(0xFFFFD93D)` allocated per-particle inside `Particle.generate` generator. Each tower hit spawns 14 particles → 14 `Paint` objects per hit, GC churn every hit. | Medium | 0.5h |
| F2 | `pixel_match_game.dart:81-90` | `update()` writes to 4 `ValueNotifier`s every single frame (health, mana, timer) regardless of whether the value changed. `ValueNotifier` does an `==` check, but `manaNotifier.value = mana` where `mana` is a double always changes due to dt regen → every listening widget (TroopCards ×4, ManaBar) rebuilds at 60 Hz. | High | 1h |
| F3 | `troop.dart:52-54` | Per-frame allocation: `(targetTower!.position - position).normalized()` creates a new `Vector2` each frame per troop, then `direction * speed * dt` creates another. 8 troops × 2 allocations × 60 fps = 960 Vector2/s. | Medium | 0.5h |
| F4 | `arena.dart:18-39` | Fallback grid rendering (when `sprite == null`) draws ~40 lines per frame with new `Paint` objects. Only triggers if sprite fails to load, but on first run / missing asset this is constant render cost. Also, no `RepaintBoundary` around the grid. | Medium (fallback only) | 0.5h |
| F5 | `tower.dart:35-46` | Fallback render path allocates `Paint()..color = color` inside a `for` loop — one Paint per brick per frame. Same sprite-missing caveat as F4. | Low–Medium | 0.25h |
| F6 | `spell.dart:55-61` | Render path allocates a `Paint` + `MaskFilter.blur` **every frame** for the glow aura. `MaskFilter.blur` is one of the most expensive ops in Skia; doing it per frame per spell is a known framerate killer. | High (when spell is active) | 0.5h |
| F7 | `pixel_match_game.dart:230-250` | `spawnTowerHit` allocates a fresh `TextComponent` with new `TextPaint`/`TextStyle`/`Shadow` on every hit. Text layout is cached by the component, but repeated allocation still hurts GC. | Low | 0.5h |
| F8 | `pixel_match_game.dart:98-101` | `AudioService.instance.escalateIfNeeded(...)` called every frame. Cheap internally (early-returns if not in `calm`), but the method lookup + two double divisions still run 60×/s. | Low | 0.25h |
| F9 | `pixel_match_game.dart:82-83` | `playerHealthNotifier.value = playerTower.health` runs every frame even though health only changes on hits. `ValueNotifier<int>` equality short-circuits the notify, so real cost is low — but still a wasted field access path. | Low | 0.1h |
| F10 | `troop.dart:27-46` | `Sprite.load` called inside `onLoad` for every spawned troop. Flame caches sprites by name so the second call is fast, but each new troop still awaits a Future on spawn which can cause first-frame visibility delay. | Low | 0.5h |

---

## Widget Rebuild Hotspots

| # | File:Line | Issue | FPS Impact | Fix Effort |
|---|-----------|-------|------------|------------|
| W1 | `battle_screen.dart:243-251` | `ValueListenableBuilder<double>` wraps every `TroopCard` on `manaNotifier`. With mana regen every frame (see F2), every card rebuilds at 60 Hz including its `AnimatedBuilder` pulse effect. Should listen once at the row level and pass a bool "ready" flag. | High | 1h |
| W2 | `battle_screen.dart:113-138` | `_cards()` rebuilds the full `List<TroopCardData>` on every `build()` call **and** is called twice per frame (once in `itemCount`, once in `itemBuilder`). Should be a `static const` / field. | Medium | 0.25h |
| W3 | `battle_screen.dart:143` | `Provider.of<UserProvider>(context)` at the top of `build` subscribes the whole battle screen to user updates. Any `userProvider.notifyListeners()` rebuilds the entire Stack including the `GameWidget` wrapper. Should be `context.select` on `user.level` only. | Medium | 0.5h |
| W4 | `battle_screen.dart:148-197` | No `RepaintBoundary` between the `GameWidget` and the HUD `Stack`. Mana bar pulses and timer tween cause the whole battle screen (including Flame render surface) to be repainted. | High | 0.25h |
| W5 | `troop_card.dart:78-145` | `AnimatedBuilder` on `_readyCtrl.repeat()` rebuilds the card's full decoration (with `BoxShadow`, `Border`, `Container`, `Column`, `Icon`, 2×`Text`) every animation tick (~60 Hz). Decoration should be split so only the shadow's alpha animates. | Medium | 1h |
| W6 | `battle_screen.dart:303-346` | `_TimerBadge` uses `TweenAnimationBuilder` that fires on every `secondsRemaining` change and restarts the tween → rebuilds its `Container` + `BoxShadow` + 2 `Text`s. Acceptable since it only ticks per second, but the shadow compositing is still expensive during the last-10-seconds pulse. | Low | 0.5h |
| W7 | `battle_screen.dart:82-88` | `_onBattleProviderUpdate` reads `Provider.of(...)` inside a listener callback and calls `_onBattleEnd`, which calls `setState` — can fire multiple times before the guard trips. | Low (correctness > perf) | 0.25h |

---

## WebSocket Reconnect Findings

Audit target: meet the Improvement 7 goal of **auto-reconnect within 3 s after mid-battle drop**.

`websocket_service.dart` is **36 lines total** and does not meet any of the required robustness properties. Specific gaps:

| Gap | Location | What's missing |
|---|---|---|
| WS-1 | `websocket_service.dart:17` | `onDone: () {}` is an **empty callback**. When the socket closes mid-battle the service silently does nothing — no reconnect, no state change, no event on the stream. **This alone fails the 3 s reconnect requirement.** |
| WS-2 | `websocket_service.dart:16` | `onError` forwards the error to the controller but does not attempt reconnection or mark the channel as dead. |
| WS-3 | entire file | No exponential backoff, no reconnect counter, no jitter. |
| WS-4 | entire file | No heartbeat / ping frame. A stalled-but-not-closed TCP connection (flaky mobile network) will never be detected. Flutter `web_socket_channel` does not send pings for you. |
| WS-5 | entire file | No connection state enum (`disconnected` / `connecting` / `connected` / `reconnecting`). `BattleProvider` has no way to show "Reconnecting…" UI. |
| WS-6 | entire file | No outbound message queue. If `send()` is called while `_channel == null` or closed, the message is silently dropped (the `?.` swallows it). During a reconnect the player's troop deploys are lost. |
| WS-7 | `websocket_service.dart:12` | `connect()` does not guard against double-connect — calling twice leaks the previous channel. |
| WS-8 | `battle_provider.dart:86` | `_cleanup()` calls `_ws.dispose()` which only closes the sink; it does not cancel the underlying stream listener if the channel is already dead. |
| WS-9 | `websocket_service.dart:13` | URL is read from `AppConstants.wsBaseUrl` at connect time — fine — but there's no timeout on the initial connect attempt. A server that accepts TCP but never upgrades to WS will hang forever. |
| WS-10 | `battle_provider.dart:29-31` | `_ws.connect()` and `_ws.joinQueue()` are called back-to-back, but `connect()` is sync and the channel's actual handshake is async. `joinQueue` likely fires before the socket is fully open; `web_socket_channel` buffers this internally, but it masks the ordering bug. |

**Verdict: the reconnect requirement is not met today.** No device test needed to confirm this — the reconnect code does not exist.

---

## Memory / Leak Suspects

| # | Location | Risk |
|---|---|---|
| M1 | `battle_screen.dart:35,94` | `_wsSub` is declared but **never assigned**. Cancelling it is a no-op; if a WS subscription were ever added here it would leak. Dead code that masks intent. |
| M2 | `audio_service.dart:45,92-94` | `_calmPlayer` / `_intensePlayer` are created by `FlameAudio.loop(...)` but only disposed in `_stopMusic()`. If the app is backgrounded / battle screen is killed without `endBattle()` firing (e.g. user hits system back before result screen), the loop players keep running and leak native audio handles. Reproduces in simulator under aggressive testing. |
| M3 | `audio_service.dart:136-150` | `_fadeTimer` (Timer.periodic) is cancelled at step-completion, but if `_stopMusic()` races with the crossfade the timer can outlive both players. `_stopMusic` does cancel it (line 101) — safe, but fragile. |
| M4 | `pixel_match_game.dart:276-281` | `onRemove` disposes the 4 `ValueNotifier`s but `BattleScreen` still holds `_game` as a field and can read `.damageDealt` / `.troopsDeployed` in the result screen **after** the notifiers are disposed. Any `ValueListenableBuilder` left mounted on a disposed notifier throws. |
| M5 | `battle_provider.dart:9,30` | `_sub` is cancelled in `_cleanup` but `WebSocketService` itself creates a **broadcast** `StreamController` that is never `close()`-ed (see `websocket_service.dart:8`). Every battle leaks one `StreamController` + its internal subscriber list. |
| M6 | `battle_screen.dart:51,93` | `bp.addListener(_onBattleProviderUpdate)` is added **only** when state is already `battleActive` at `initState` time. If the state transitions to `battleActive` *after* init (e.g. matchmaking finalises late), the listener is never added and the battle never ends cleanly. Not a leak, but a stuck-state risk. |
| M7 | `pixel_match_game.dart:209-228` | `ParticleSystemComponent`s are added but rely on Flame's built-in `shouldRemove` from particle lifespan. If `pauseEngine()` is called mid-particle (battle end), particles stay on the component tree until `_game` itself is removed. Minor. |
| M8 | `battle_screen.dart:96` | `AudioService.instance.reset()` disposes music players but the singleton itself persists. Across 10 matches this is fine; across app-wide navigation churn it's still only one instance. OK. |

---

## Instrumentation Plan

To convert this static audit into real numbers, a human with a physical mid-range Android (target: Pixel 4a / Galaxy A34 / equivalent, Android 12+) should run the following, in order. Each step produces a concrete artefact to paste back into this doc.

### Step 1 — Device setup (once)
```bash
flutter devices                                  # confirm device is listed
flutter pub get
```
Enable Developer Options → USB debugging. Plug in. Close background apps.

### Step 2 — Profile build
```bash
cd pixel_match
flutter run --profile -d <device-id>
```
`--profile` is mandatory. `--debug` doubles every frame time and is useless for perf work. `--release` strips the Observatory hooks DevTools needs.

### Step 3 — Frame chart (battle FPS)
1. In the terminal output of `flutter run --profile`, open the DevTools URL.
2. Go to **Performance** tab → press **Record**.
3. In the app: start a battle (`/battle`), play ~60 seconds deploying troops and casting spells, then stop.
4. Record: **average FPS**, **worst 1% frame time**, count of frames >16 ms and >33 ms.
5. Expand the worst frame in the flame chart. Note the top frame-time contributor (expect: `PixelMatchGame.update`, `TroopCard build`, or `Spell.render`).

**Expected numbers if the hotspots above are real:**
- Average FPS: 45-55 (target is 55+)
- Worst 1%: 30-40 ms (target <22 ms)
- Dominant cost: widget rebuilds from mana notifier (F2/W1) + spell blur (F6)

### Step 4 — Widget rebuild counts
In DevTools → **Performance** → enable **Track Widget Builds**. Run the same 60 s battle. Note the top 5 widgets by rebuild count. Expect `TroopCard` and `_ManaBar` at >3000 rebuilds each (60 Hz × 60 s).

### Step 5 — Memory over 10 matches
1. DevTools → **Memory** → **Take snapshot** before first battle.
2. Play 10 battles back-to-back (single-player is fine; AI spawns after 3 s).
3. Take a second snapshot. Compare **Dart heap** and **native memory**.
4. Target: <20 MB growth. Watch specifically for:
   - Retained `StreamController` instances (should be 0 after match ends — see M5)
   - Retained `AudioPlayer` instances (should be 0 — see M2)
   - Retained `PixelMatchGame` instances (should be 1, the current one)

### Step 6 — WebSocket reconnect simulation
1. Start a multiplayer battle.
2. With adb in another shell:
   ```bash
   adb shell svc wifi disable
   sleep 2
   adb shell svc wifi enable
   ```
   Or toggle airplane mode via the notification shade.
3. Measure time from disable → next successful server message round-trip. Target **≤3 s**.
4. **Expected result today: infinite — the client will never reconnect** (see WS-1). This is the most important gap to fix.

### Step 7 — Battery / thermal
`adb shell dumpsys batterystats --reset` before a 10-minute battle session, then `adb shell dumpsys batterystats | grep -A5 pixel_match`. Record mAh delta. No target set yet; capture for baseline.

### Step 8 — `flutter drive` (optional)
Only worth it once there's a scripted battle flow. Skip for the first pass.

---

## Fix Shortlist (effort <1 day, impact >5 FPS)

Ranked by estimated FPS recovery per hour of work. Each item is self-contained and ready to hand to the fix agent. File and line references are from the snapshots read during this audit — the fix agent should re-read around the line before editing.

### #1 — Wrap `GameWidget` in a `RepaintBoundary` and split the HUD
**Files:** `pixel_match/lib/screens/battle/battle_screen.dart:148-197`
**Estimated impact:** High (8-12 FPS recovery on mid-range)
**Effort:** 15 min
**Change:** Wrap `GameWidget(...)` in `RepaintBoundary`. Wrap each `ValueListenableBuilder` HUD subtree (`_topHud`, `_bottomHud`) in its own `RepaintBoundary`. This stops mana/timer widget repaints from invalidating Flame's render surface.
**Ref finding:** W4.

### #2 — Stop rebuilding `TroopCard` per frame on mana changes
**Files:** `pixel_match/lib/screens/battle/battle_screen.dart:236-252`, `pixel_match/lib/widgets/troop_card.dart:53-73`
**Estimated impact:** High (5-10 FPS — four cards × 60 Hz rebuild is the single biggest widget cost)
**Effort:** 45 min
**Change:**
1. Replace the per-card `ValueListenableBuilder<double>` with a single `ValueListenableBuilder<bool>` at the `ListView` level that computes `ready = mana >= cost` once and passes a `bool` down.
2. Change `TroopCard` to take `bool ready` instead of `double currentMana`, so Flutter's `==` check on the widget props short-circuits the rebuild 99% of the time.
3. Alternative quick version: wrap the `ValueListenableBuilder` in a `Selector`-style `distinct` adapter so it only fires when the `ready` bool flips, not on every double tick.
**Ref findings:** F2, W1.

### #3 — Hoist the `Paint` in `spawnTowerHit` particles and kill the per-frame blur in `Spell.render`
**Files:** `pixel_match/lib/game/pixel_match_game.dart:220-224`, `pixel_match/lib/game/components/spell.dart:55-61`
**Estimated impact:** High while a spell is in flight (10-20 FPS on the spell's 1-2 s travel), Medium during particle bursts
**Effort:** 30 min
**Change:**
1. In `pixel_match_game.dart`, hoist `static final Paint _hitParticlePaint = Paint()..color = const Color(0xFFFFD93D);` to the class and reuse it in `CircleParticle(paint: _hitParticlePaint)`.
2. In `spell.dart`, move the glow `Paint` (with `MaskFilter.blur`) to a `static final` field. Even better: replace the live `MaskFilter.blur` with a pre-rendered radial-gradient sprite or drop the blur entirely — blur is the single most expensive per-frame op in Skia.
**Ref findings:** F1, F6.

### #4 — Cache the troop card list
**Files:** `pixel_match/lib/screens/battle/battle_screen.dart:113-138, 239, 242`
**Estimated impact:** Medium (2-4 FPS — removes 8 List allocs per frame)
**Effort:** 10 min
**Change:** Move `_cards()` to a `static const List<TroopCardData> _kCards = [...]` at file scope (already const-constructible). Call sites become `_kCards.length` and `_kCards[i]`.
**Ref finding:** W2.

### #5 — Minimal WebSocket reconnect + heartbeat
**Files:** `pixel_match/lib/services/websocket_service.dart:1-36` (full rewrite), `pixel_match/lib/providers/battle_provider.dart:29-31` (gains a connection state stream)
**Estimated FPS impact:** 0 — but this is the one hard blocker for the Improvement 7 goal, so it belongs in the shortlist.
**Effort:** 4-6 h
**Change:**
1. Add a `ConnectionState` enum + `ValueNotifier<ConnectionState>`.
2. In `onDone` / `onError`, schedule a reconnect with exponential backoff: 500 ms → 1 s → 2 s → 4 s, capped at 8 s, with ±20% jitter. This meets the 3 s target on the first retry.
3. Add a `Timer.periodic` heartbeat every 20 s that sends `{'type': 'ping'}`. Server must respond with `pong`; if no pong for 30 s, force-reconnect.
4. Add a `Queue<Map>` outbound buffer. When `send()` is called in a non-connected state, push to the queue; drain the queue on reconnect.
5. Guard `connect()` against double-connect (bail if `_channel != null && state != disconnected`).
6. Close the broadcast `StreamController` in `dispose()` to fix M5.
**Ref findings:** WS-1 through WS-10, M5.

### #6 — Reuse `Vector2` scratch buffers in `Troop.update`
**Files:** `pixel_match/lib/game/components/troop.dart:49-60`
**Estimated impact:** Medium (2-4 FPS with 8+ troops on screen, mostly via reduced GC pauses)
**Effort:** 20 min
**Change:** Cache a `final Vector2 _scratch = Vector2.zero();` on the troop and use `..setFrom(targetTower!.position)..sub(position)..normalize()..scale(speed * dt)` then `position.add(_scratch)`. Same trick for `Spell.update`.
**Ref finding:** F3.

---

**Items deliberately left off the shortlist** (effort too high or impact too low per the <1 day / >5 FPS gate):
- F4/F5 (fallback render paint allocs) — only triggered when sprites fail to load, which is a packaging bug not a perf bug.
- F10 (sprite per-spawn load) — Flame caches, real cost is <1 ms; would require a sprite registry refactor.
- W5 (TroopCard `AnimatedBuilder` decoration split) — moderate impact but the refactor is >1h and partially overlaps with fix #2.
- M6 (battle listener race) — correctness issue, should be a separate ticket filed under the matchmaking flow.

---

**Audit completed:** static code review only. Device measurements still pending — see Instrumentation Plan. The top three items alone (RepaintBoundary + TroopCard rebuild + Spell blur) should recover an estimated 15-25 FPS on a mid-range Android and take under 2 hours combined.
