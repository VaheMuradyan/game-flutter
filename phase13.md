# Phase 13 — UI Design System with Google Stitch MCP

## Goal
Use the Google Stitch MCP tools to create a cohesive design system and generate polished screen designs for every major screen in the app. Capture the design decisions in a reference document that guides future Flutter UI updates. When this phase is complete, you have a full set of screen mockups and a design system that defines the visual language of PixelMatch.

> **IMPORTANT:** Google Stitch generates **UI screen layouts and design systems** (colors, typography, spacing, component styles). It does **NOT** generate pixel-art sprites, character art, or game assets. Sprite creation is covered separately in Phase 14.

> **NO FLUTTER CODE CHANGES IN THIS PHASE.** This phase produces design references only. Code updates based on these designs happen incrementally as you iterate.

## Prerequisites
Phases 11–12 complete: codebase is clean, environment config works, all features functional.

---

## 1. Create a Stitch Project

Use the `create_project` MCP tool to set up a workspace for all PixelMatch screens.

```
Tool: mcp__google-stitch__create_project
Parameters:
  title: "PixelMatch - Dating Battle Game"
  description: "A real-time multiplayer dating + tower-defense battle game with pixel-art dark theme. 5 character classes, swipe matching, 1v1 battles, chat, and leaderboards."
```

Save the returned `projectId` — you'll need it for all subsequent calls.

---

## 2. Create the Design System

Define the visual language to match the existing Flutter theme (`lib/config/theme.dart`).

```
Tool: mcp__google-stitch__create_design_system
Parameters:
  projectId: <projectId from step 1>
  name: "PixelMatch Dark"
  colorMode: "DARK"
  customColor: "#FF6B6B"
  headlineFont: "SPACE_GROTESK"
  bodyFont: "SPACE_GROTESK"
  roundness: "ROUND_FOUR"
  designMd: |
    # PixelMatch Design System

    ## Brand Identity
    A retro pixel-art inspired dating/battle game. The aesthetic is dark, moody, and game-themed
    with bright accent colors for interactive elements.

    ## Color Palette
    - Primary (Red): #FF6B6B — buttons, highlights, destructive actions
    - Secondary (Teal): #4ECDC4 — success states, health bars, positive actions  
    - Accent Gold: #FFD93D — premium features, XP, achievements
    - Background: #1A1A2E — main app background (deep navy)
    - Surface: #16213E — cards, bottom nav, input fields
    - Text Primary: #E8E8E8
    - Text Secondary: #9E9E9E

    ## League Colors
    - Bronze: #CD7F32
    - Silver: #C0C0C0
    - Gold: #FFD700
    - Diamond: #B9F2FF
    - Legend: #FF6B6B

    ## Typography
    - The real app uses "Press Start 2P" (Google Fonts) — a pixel bitmap font
    - In Stitch, use Space Grotesk as the closest available match
    - Headlines: bold, uppercase where appropriate
    - Body: regular weight, 14-16px equivalent

    ## Component Style
    - Cards: 8px border radius, surface color background, subtle league-colored borders
    - Buttons: Full-width primary, 64px height, rounded
    - Avatars: Circular, 64px, with league-color ring border
    - Health bars: Rounded, color-coded (green > 50%, orange > 25%, red < 25%)
    - XP bars: Thin (8px), league-colored fill

    ## Layout Principles
    - Single column, mobile-first
    - 24px horizontal padding
    - 16px spacing between components
    - Bottom navigation: 4 tabs (Arena, Browse, Chats, Profile)
```

---

## 3. Apply the Design System

```
Tool: mcp__google-stitch__apply_design_system
Parameters:
  projectId: <projectId>
  designSystemId: <designSystemId from step 2>
```

---

## 4. Generate Screen Designs

Generate each major screen one at a time. Save the returned `screenId` for each.

### 4a. Welcome / Login Screen

```
Tool: mcp__google-stitch__generate_screen_from_text
Parameters:
  projectId: <projectId>
  prompt: |
    Welcome screen for a dark-themed pixel-art dating battle game called "PixelMatch".
    
    Layout:
    - Deep navy background (#1A1A2E)
    - Large game logo/title "PixelMatch" at top with a crossed-swords icon
    - Tagline: "Level up your love life" in secondary text color
    - Pixel-art style decorative elements (subtle)
    - Email input field with dark surface background
    - Password input field
    - Large red "SIGN UP" button (#FF6B6B), full width, 64px height
    - "Already have an account? LOG IN" text link below
    - Subtle animated particles or pixel effects in background
```

### 4b. Character Class Selection

```
Tool: mcp__google-stitch__generate_screen_from_text
Parameters:
  projectId: <projectId>
  prompt: |
    Character class selection screen for a pixel-art RPG dating game.
    Dark background (#1A1A2E).
    
    Header: "Choose Your Class" in bold
    
    5 selectable class cards in a vertical list, each card showing:
    - Class icon (shield for Warrior, wand for Mage, bow for Archer, dagger for Rogue, cross for Healer)
    - Class name in bold
    - Short description (e.g., "Warrior — Strong and steadfast")
    - Card background: #16213E surface color
    - Selected card: highlighted border in #FF6B6B
    
    Bottom: "CONTINUE" button, full width, #FF6B6B, disabled until a class is selected
```

### 4c. Home / Arena Screen

```
Tool: mcp__google-stitch__generate_screen_from_text
Parameters:
  projectId: <projectId>
  prompt: |
    Main home screen for a pixel-art battle game. Dark theme (#1A1A2E background).
    
    Top section: Player info card with:
    - Circular avatar (64px) with league-colored ring border
    - Display name and "Warrior · Gold" class/league text
    - XP progress bar (thin, gold colored) showing "Lv 35 · 3450 XP"
    - Circular level badge (48px) on the right with number inside
    
    Center: Large "FIND BATTLE" button with game controller icon, full width, 64px, red (#FF6B6B)
    
    Stats row: Three equal cards showing "24 Wins" (teal), "12 Losses" (red), "Gold League" (gold)
    
    Quick links: "Leaderboard" and "Battle History" list tiles with icons
    
    Bottom navigation bar: 4 tabs — Arena (active, red), Browse (heart), Chats, Profile
    Dark surface background (#16213E)
```

### 4d. Match Browser (Swipe)

```
Tool: mcp__google-stitch__generate_screen_from_text
Parameters:
  projectId: <projectId>
  prompt: |
    Tinder-style swipe card interface for a pixel-art dating battle game.
    Dark background (#1A1A2E).
    
    Main card (centered, takes up most of screen):
    - User photo area (top 60% of card)
    - Below photo: Display name "DragonSlayer99" in bold
    - Character class badge: "Mage" with icon
    - Level badge with league color ring
    - Stats row: "15W / 3L · 83% WR"
    - Card background: #16213E
    - Rounded corners (8px)
    
    Swipe indicators:
    - Green "LIKE" text rotated on right side when swiping right
    - Red "NOPE" text rotated on left side when swiping left
    
    Bottom: "12 swipes remaining today" counter text
    
    Bottom navigation bar: Browse tab active
```

### 4e. Battle HUD

```
Tool: mcp__google-stitch__generate_screen_from_text
Parameters:
  projectId: <projectId>
  prompt: |
    Battle game HUD overlay for a pixel-art tower defense game.
    Dark background representing the battle arena.
    
    Top: Enemy tower health bar (wide, showing "Enemy 850/1000 HP"), red when low
    Top-right: Battle timer "2:34" countdown
    
    Center: The arena area (abstract representation — dark grid pattern)
    
    Bottom area:
    - Player tower health bar "You 1000/1000 HP" in green
    - Blue mana bar below it "MANA 7/10"
    - "Spell" button (gold, mini floating action button) on the right
    
    Style: Dark, game-themed, minimal chrome, focus on gameplay area
    All HUD elements use pixel/retro styling
```

### 4f. Profile Screen

```
Tool: mcp__google-stitch__generate_screen_from_text
Parameters:
  projectId: <projectId>
  prompt: |
    Gamer profile screen for a pixel-art dating battle game.
    Dark background (#1A1A2E).
    
    Top: Large circular avatar (96px) with league-colored border ring (gold for Gold league)
    Edit icon overlay on avatar corner
    
    Below avatar:
    - Display name "PixelKnight" centered, bold
    - "Warrior · Gold League" in gold text
    - Level badge: "Lv 35" in a circular badge
    
    XP Progress bar: Full width, gold fill, "3450 / 3500 XP" label
    
    Stats grid (2x2):
    - Wins: 24 (teal)
    - Losses: 12 (red)  
    - Win Rate: 67% (white)
    - Battles: 36 (white)
    
    Buttons:
    - "Battle History" list tile with icon
    - "Edit Display Name" list tile
    - "Sign Out" button at bottom (red outline)
    
    Bottom navigation: Profile tab active
```

### 4g. Chat Screen

```
Tool: mcp__google-stitch__generate_screen_from_text
Parameters:
  projectId: <projectId>
  prompt: |
    In-app chat screen for a pixel-art dating battle game.
    Dark background (#1A1A2E).
    
    Top bar: Back arrow, opponent avatar (small circle), opponent name "MageQueen42", online status dot
    
    Message area (scrollable):
    - Incoming messages: left-aligned, surface color (#16213E) bubbles, rounded
    - Outgoing messages: right-aligned, primary color (#FF6B6B) bubbles, rounded
    - Timestamps below message groups
    - Emote messages shown larger (sword ⚔️, heart ❤️, fire 🔥 etc.)
    
    Bottom input area:
    - Row of 8 pixel emote buttons (small, scrollable horizontal)
    - Text input field with dark surface background
    - Send button (teal #4ECDC4)
    
    Game-themed: subtle pixel border accents
```

### 4h. Leaderboard Screen

```
Tool: mcp__google-stitch__generate_screen_from_text
Parameters:
  projectId: <projectId>
  prompt: |
    Leaderboard screen for a pixel-art battle game.
    Dark background (#1A1A2E).
    
    Top: Tab bar with "Global" and league tabs (Bronze, Silver, Gold, Diamond, Legend)
    Each tab colored to match its league
    
    List items (ranked 1-50):
    - Rank number (gold for top 3, white otherwise)
    - Small avatar circle
    - Display name + character class badge
    - Level and XP on the right
    - Subtle row highlight for the current user
    
    Top 3 players have a special crown/medal icon next to rank
    
    Style: Clean list, dark surface row backgrounds, slight spacing between rows
```

---

## 5. Generate Variants for Key Screens

Pick the 2–3 most important screens (Welcome, Home, Battle HUD) and iterate.

```
Tool: mcp__google-stitch__generate_variants
Parameters:
  projectId: <projectId>
  screenId: <welcomeScreenId>
  creativeRange: "REFINE"
  aspects: ["LAYOUT", "COLOR_SCHEME"]
```

```
Tool: mcp__google-stitch__generate_variants
Parameters:
  projectId: <projectId>
  screenId: <homeScreenId>
  creativeRange: "REFINE"
  aspects: ["LAYOUT"]
```

```
Tool: mcp__google-stitch__generate_variants
Parameters:
  projectId: <projectId>
  screenId: <battleHudScreenId>
  creativeRange: "REFINE"
  aspects: ["LAYOUT", "COLOR_SCHEME"]
```

---

## 6. Review and Select Final Designs

Use `list_screens` and `get_screen` to review all generated screens and variants:

```
Tool: mcp__google-stitch__list_screens
Parameters:
  projectId: <projectId>
```

For each screen, review the design and note:
- Which variant (if any) is preferred
- What colors, spacing, or layout changes to adopt in Flutter code
- Any new UI patterns discovered (e.g., better stat card layout)

---

## 7. Document Design Decisions

Create a design reference file at the project root summarizing the adopted designs.

### `design_reference.md`

```markdown
# PixelMatch Design Reference

Generated via Google Stitch MCP on [date].

## Stitch Project
- Project ID: [projectId]
- Design System ID: [designSystemId]

## Adopted Screen Designs

| Screen | Screen ID | Variant | Key Changes from Current |
|--------|-----------|---------|--------------------------|
| Welcome | [id] | Original / Variant A | [notes] |
| Class Selection | [id] | Original | [notes] |
| Home / Arena | [id] | Variant B | [notes] |
| Match Browser | [id] | Original | [notes] |
| Battle HUD | [id] | Variant A | [notes] |
| Profile | [id] | Original | [notes] |
| Chat | [id] | Original | [notes] |
| Leaderboard | [id] | Original | [notes] |

## Color Palette (Final)
- Primary: #FF6B6B
- Secondary: #4ECDC4
- Accent: #FFD93D
- Background: #1A1A2E
- Surface: #16213E

## Spacing Rules
- Screen padding: 24px
- Card padding: 16px
- Element spacing: 16px (standard), 8px (tight)
- Button height: 64px (primary), 48px (secondary)

## Typography
- Font: Press Start 2P (Google Fonts)
- Title: 16px
- Body: 12px
- Label: 10px

## Component Patterns
- [Any new patterns discovered from Stitch output]
```

---

## 8. Verification Checklist

### Stitch Project
- [ ] Project created successfully with `create_project`
- [ ] Design system created with correct colors and settings
- [ ] Design system applied to project

### Screen Generation
- [ ] Welcome screen generated
- [ ] Class selection screen generated
- [ ] Home / Arena screen generated
- [ ] Match browser (swipe) screen generated
- [ ] Battle HUD screen generated
- [ ] Profile screen generated
- [ ] Chat screen generated
- [ ] Leaderboard screen generated

### Variants
- [ ] At least 2 screens have variants generated
- [ ] Variants reviewed and best option noted

### Documentation
- [ ] `design_reference.md` created with all screen IDs
- [ ] Design decisions documented for each screen
- [ ] Color palette confirmed (matches theme.dart)

---

## What Phase 14 Expects
A complete set of UI screen designs providing visual direction. The design system colors and patterns inform the pixel-art sprite style in Phase 14.

## Files Created in This Phase
```
game-flutter/
└── design_reference.md    (design decisions + Stitch screen IDs)
```

## What This Phase Does NOT Create
- Pixel-art sprites or character art (Phase 14)
- Audio assets (Phase 14)
- Flutter code changes (applied incrementally later)
