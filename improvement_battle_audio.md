# Improvement 3 — Adaptive Battle Audio

## Context
The app currently ships with no in-battle audio. Music and SFX are the cheapest way to make a game feel alive, and adaptive music (shifts intensity on tower damage / final 30s) creates tension that matches the core loop. This track adds a lean audio layer without pulling in heavy middleware.

## Goal
Every meaningful battle event has an SFX. Background music has at least two intensity layers that cross-fade based on game state. Audio respects device mute and a user toggle.

## Scope
### In
- Background music: calm layer + intense layer, cross-faded by match state
- SFX: troop deploy, troop march, tower hit (2 variants), tower destroyed, victory sting, defeat sting, countdown ticks (last 5s)
- Settings toggle: music on/off, SFX on/off (persist in SharedPreferences)
- Respect system mute on iOS/Android

### Out
- Voice lines / announcer
- Menu music
- Licensed tracks — use royalty-free or commissioned assets only

## Files to Touch
- `pixel_match/pubspec.yaml` — add `flame_audio` (already likely present via Flame) or `audioplayers`
- `pixel_match/assets/audio/` — new folder for music + SFX
- `pixel_match/lib/services/audio_service.dart` — **new** singleton managing layers
- `pixel_match/lib/screens/battle_screen.dart` — trigger events
- `pixel_match/lib/screens/settings_screen.dart` — toggles

## Approach
1. Invoke `game-audio-engineer` for: asset sourcing plan, layer cross-fade algorithm, latency budget per SFX, file format recommendation (ogg for Android, m4a for iOS, or unified mp3).
2. Build `AudioService` with a simple state machine: `idle → calm → intense → ended`. Transitions triggered from battle WebSocket events.
3. Keep total audio payload under **3 MB** to protect app size.
4. Test on a real Android device — emulator audio latency is unrepresentative.

## Verification
- Play a full match: music cross-fades correctly when either tower drops below 50% HP.
- Mute toggle in settings persists across app restarts.
- App size delta < 3 MB (`flutter build apk --analyze-size`).
- No audio stutter on mid-range Android (test on one real device).
