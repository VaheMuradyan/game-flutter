# PixelMatch

A real-time multiplayer dating + tower-defense battle game built with Flutter and Go.

## Architecture

- **Frontend:** Flutter (Flame game engine, Provider state management, GoRouter)
- **Backend:** Go (Gin HTTP, Gorilla WebSocket, PostgreSQL)
- **Auth:** JWT tokens stored in SharedPreferences

## Running Locally

### Backend

```bash
cd pixelmatch-server
export DB_HOST=localhost DB_USER=pixelmatch DB_PASSWORD=pixelmatch_secret_2024 DB_NAME=pixelmatch
go run main.go
```

### Frontend

```bash
cd pixel_match
flutter pub get
flutter run --dart-define=API_HOST=http://10.0.2.2:8080 --dart-define=WS_HOST=ws://10.0.2.2:8080
```

## Features

- Register / login with email + password (JWT)
- Choose character class (Warrior, Mage, Archer, Rogue, Healer)
- Real-time 1v1 tower-defense battles via WebSocket
- Swipe-based profile matching (Tinder-style)
- In-app chat with text and pixel emotes
- XP / level / league progression system
- Global and league leaderboards
- Profile photo upload

## Project Structure

```
pixel_match/lib/
├── config/       # Theme, routes, constants, API client
├── game/         # Flame engine: arena, tower, troop, spell
├── models/       # Data classes (User, Battle, Match, Message)
├── providers/    # State management (Auth, User, Battle, Match, Chat)
├── screens/      # UI screens (onboarding, home, battle, browse, chat, profile, leaderboard)
├── services/     # API communication layer
├── utils/        # XP calculator, league helper, photo URL helper
└── widgets/      # Reusable components (PixelCard, LevelBadge, HealthBar, SwipeCard)
```
