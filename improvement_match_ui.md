# Improvement 4 — Swipe / Match Screen Refresh

## Context
The dating side of PixelMatch is the top of the funnel — it's what players see before they ever touch the battle screen. A polished swipe experience (card stack physics, photo loading, match celebration) directly drives retention into the battle loop. Current implementation is functional from phase work but visually undifferentiated from any generic dating app.

## Goal
Swipe feels tactile. Photos load without jank. The "It's a Match" moment is celebratory and pushes players toward a first battle.

## Scope
### In
- Card stack with physics-based swipe (tilt, release velocity, snap-back)
- Progressive photo loading with blurhash or low-res placeholder
- "It's a Match" screen with animation and "Battle Now" CTA
- Daily swipe counter visible on the swipe screen
- Empty state when swipes exhausted

### Out
- Matching algorithm changes
- Photo upload flow
- Profile edit screen

## Files to Touch
- `pixel_match/lib/screens/swipe_screen.dart`
- `pixel_match/lib/widgets/profile_card.dart` (or equivalent)
- `pixel_match/lib/widgets/match_celebration.dart` — **new**
- `pixel_match/lib/services/api_client.dart` — only if photo URL response needs blurhash field
- `pixelmatch-server/handlers/likes.go` — optional, return blurhash in profile payload

## Approach
1. Invoke `design-ui-designer` with Stitch to produce: swipe card, match celebration, empty state. Save under `design_reference/match/`.
2. Use `flutter_card_swiper` or equivalent for physics. Do not hand-roll.
3. Add `cached_network_image` if not already present for photo caching.
4. Celebrate-screen animation: scale-in hearts, confetti via Flame or `confetti` package.
5. If backend lacks blurhash, ship with plain placeholder color — do not block on server changes.

## Verification
- `flutter run -d chrome`: swipe 10 profiles, confirm smooth physics, no dropped frames (DevTools frame chart).
- Trigger a match, confirm celebration screen shows and CTA navigates to battle queue.
- Exhaust daily swipes, confirm empty state.
- `flutter analyze` clean.
