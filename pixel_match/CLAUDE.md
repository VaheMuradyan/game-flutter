# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PixelMatch is a Flutter-based dating/battle hybrid game. Users pick a character class, swipe to match with others, chat with matches, and battle opponents in a real-time tower-defense mini-game. It connects to a Go backend server (separate repo at `/root/pixelmatch-server`) via REST + WebSocket.

## Common Commands

```bash
# Run the app (web is easiest for dev)
flutter run -d chrome
flutter run -d linux

# Analyze code
flutter analyze

# Run tests
flutter test
flutter test test/widget_test.dart   # single test

# Get dependencies
flutter pub get
```

## Architecture

**State management:** Provider (`ChangeNotifierProvider`) — five top-level providers registered in `lib/app.dart`:
- `AuthProvider` — login/register/onboarding, holds current `UserModel`, JWT via `SharedPreferences`
- `UserProvider` — browsing other users, profile updates
- `BattleProvider` — matchmaking queue state machine (`idle → searching → battleActive → battleEnded`), wraps `WebSocketService`
- `MatchProvider` — swipe likes/matches via `MatchmakingService`
- `ChatProvider` — chat rooms and messages

**Routing:** `go_router` in `lib/config/routes.dart`. Auth guard redirects unauthenticated users to `/`, un-onboarded users to `/onboarding/class`. Main app uses a `ShellRoute` with tab navigation (`/home`, `/browse`, `/chats`, `/profile`). Full-screen routes sit outside the shell (`/battle`, `/battle/queue`, `/chat/:chatId`, `/leaderboard`).

**Networking:**
- `lib/config/api_client.dart` — static HTTP client wrapping `package:http`, auto-attaches JWT from `SharedPreferences`. All services call through this.
- `lib/services/websocket_service.dart` — WebSocket client for real-time battle events. Connects to `/ws/battle`, exposes a broadcast stream of decoded JSON messages.

**Game engine:** Flame (`lib/game/`). `PixelMatchGame` is a `FlameGame` with tap-to-deploy troops, mana management, and tower health tracking. Supports both single-player (AI spawns enemy troops on a timer) and multiplayer (server relays troop deployments and tower hits).

**Services layer** (`lib/services/`) — `AuthService`, `UserService`, `ChatService`, `MatchmakingService`, `WebSocketService`. Each service calls `ApiClient` for HTTP or manages WebSocket connections.

**Models** (`lib/models/`) — `UserModel`, `BattleModel`, `MatchModel`, `MessageModel`. All have `fromJson` factories for API deserialization.

## Key Configuration

- **Server URL:** `lib/config/constants.dart` — `apiBaseUrl` and `wsBaseUrl` must be set to the backend server address before running.
- **Theme:** `lib/config/theme.dart` — dark theme using `PressStart2P` pixel font via `google_fonts`. League colors (Bronze/Silver/Gold/Diamond/Legend) defined here.
- **Game constants** (XP values, battle duration, mana, league ranges, character classes, swipe limits) are all in `lib/config/constants.dart`.

## Conventions

- Screens organized by feature in `lib/screens/<feature>/`
- Reusable widgets in `lib/widgets/` (health bars, level badges, pixel cards, swipe cards)
- Lint rules from `package:flutter_lints`
- Assets in `assets/images/`, `assets/sprites/`, `assets/audio/`, `assets/fonts/`
