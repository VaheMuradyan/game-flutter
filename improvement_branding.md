# Improvement 6 — Brand Identity & Logo

## Context
PixelMatch has no consistent brand identity — no logo, no defined palette, no type system. Before any store listing or marketing surface exists, the app needs a coherent look that ties the dating and battle halves together into one recognizable product.

## Goal
A small but complete brand kit: logo (wordmark + icon), primary palette, secondary palette, typography, and a Flutter `ThemeData` that every screen consumes.

## Scope
### In
- Logo exploration (wordmark + app icon)
- 5–7 color palette with semantic roles (primary, accent, danger, success, surface, text)
- Type ramp (display, title, body, caption)
- Flutter `ThemeData` central file
- App icons generated for Android + iOS + web
- Splash screen

### Out
- Marketing site
- Store screenshots
- Animated splash / intro cinematic

## Files to Touch
- **New:** `pixel_match/lib/theme/app_theme.dart` — central `ThemeData`
- **New:** `pixel_match/lib/theme/app_colors.dart`
- `pixel_match/lib/main.dart` — apply `theme:` argument
- `pixel_match/assets/brand/` — logo SVG/PNG
- `pixel_match/android/app/src/main/res/` — launcher icons
- `pixel_match/ios/Runner/Assets.xcassets/` — app icon set
- Sweep existing screens to replace hardcoded colors with theme tokens

## Approach
1. Invoke **`logo_search` MCP** with "PixelMatch dating battle game" — use as inspiration, not final output.
2. Invoke `design-ui-designer` for: palette selection, logo direction (1 chosen concept, not a moodboard), type pairing.
3. Generate launcher icons with `flutter_launcher_icons` package.
4. Generate splash with `flutter_native_splash`.
5. Find-and-replace hardcoded `Color(0xFF...)` / `Colors.xxx` in existing screens with theme tokens. This is mechanical but must not be skipped — the whole point is consistency.

## Verification
- Every screen visually uses the new palette (manual smoke test of swipe, chat, battle, profile screens).
- `grep -r "Color(0xFF" pixel_match/lib/screens` returns zero (or only documented exceptions).
- Launcher icon shows on Android emulator install.
- `flutter analyze` clean.
