# PixelMatch Design Reference

Generated via Google Stitch MCP on 2026-04-12.

## Stitch Project
- Project ID: `6342841629597121755`
- Design System ID: `3953669719746129272`
- Design System Name: PixelMatch Dark

## Adopted Screen Designs

| Screen | Screen ID | Variant | Key Design Notes |
|--------|-----------|---------|------------------|
| Welcome / Login | `32b200836c06424ca1ec0e346813e571` | Original | Crossed-swords logo, email/password fields on dark surface, full-width red SIGN UP button, pixel grid background texture |
| Class Selection | `8c308e0af8f9434eb9c7f82b15efa26e` | Original | 5 vertical class cards with icons, selected state uses #FF6B6B border, CONTINUE button at bottom |
| Home / Arena | `eeafe4a099224fe584f34324d53e48df` | Variant C (`f306a2cb3a784997aead047812d0517f`) | Player card + stats consolidated into single block, FIND BATTLE button stands alone with breathing room, better visual hierarchy |
| Match Browser | `dfdb0844f99b41729b331d61f5914139` | Original | Large swipe card with photo area, class badge, level ring, win stats. LIKE/NOPE swipe indicators. Swipe counter at bottom |
| Battle HUD | `edfda2722d604409a8a1c25ebd57301c` | Variant A (`df8e0176f2fd4ce5bfb1de504246fbe1`) | Tactical commander layout: wide enemy HP bar at top, timer top-right in angular panel, player HP/mana stacked bottom-left, spell button bottom-right with metallic sheen |
| Profile | `d766803e61f142e3a15db05c7c68b1f4` | Original | Large 96px avatar with gold ring, centered name/class, XP progress bar, 2x2 stats grid, action list tiles, sign out at bottom |
| Chat | `397b5cbfaa324cf383f6315d5ef5b868` | Original | Back arrow + avatar + name + online dot in top bar. Left/right message bubbles (#16213E incoming, #FF6B6B outgoing). Emote row + text input + teal send button at bottom |
| Leaderboard | `28a1c2aaeefd45348a564bf9b4bcd13b` | Original | League tab bar (Global + 5 leagues), crown/medal icons for top 3, highlighted current user row, clean list with surface-colored rows |

## Welcome Screen Variants
| Variant | Screen ID | Notes |
|---------|-----------|-------|
| A | `be45615dfae442feb74ba79643af13bb` | Horizontal logo with icon left of text, form fields grouped in secondary-color bordered container |
| B | `5cc1d446632b46f99f338ba4a43d70a4` | Deeper red CTA button, gold outline on focused inputs, teal LOG IN link |
| C | `a58faa85128d4a9a82fd2460b2e0e670` | Narrower centered form column with more negative space, gold outline on SIGN UP button |

## Home Screen Variants
| Variant | Screen ID | Notes |
|---------|-----------|-------|
| A | `c5cb566ccf0b4ca1855291b403b115c2` | FIND BATTLE button moved to top as primary focal point, player card below |
| B | `3a78c9028abe41aab3ad2c781a99bdc9` | Stats row elevated to top, performance-first layout |
| C | `f306a2cb3a784997aead047812d0517f` | Player card + stats consolidated, battle button isolated with whitespace (ADOPTED) |

## Battle HUD Variants
| Variant | Screen ID | Notes |
|---------|-----------|-------|
| A | `df8e0176f2fd4ce5bfb1de504246fbe1` | Tactical commander — angular panels, compact player bars bottom-left, textured spell button (ADOPTED) |
| B | `a717db7b85d94d5b9d00719f8da38e89` | Immersive — full-width enemy bar, centered timer, semi-transparent player bars, centered spell button |
| C | `00b4f03c4e364ca6b2943fa48734ee09` | Diagnostic overlay — minimal numeric readouts, thin top bar, spell as ability slot |

## Color Palette (Final)
- Primary: `#FF6B6B` (red — buttons, highlights)
- Secondary: `#4ECDC4` (teal — success, health bars)
- Accent: `#FFD93D` (gold — XP, achievements, premium)
- Background: `#1A1A2E` (deep navy)
- Surface: `#16213E` (cards, inputs, bottom nav)
- Text Primary: `#E8E8E8`
- Text Secondary: `#9E9E9E`

## League Colors
- Bronze: `#CD7F32`
- Silver: `#C0C0C0`
- Gold: `#FFD700`
- Diamond: `#B9F2FF`
- Legend: `#FF6B6B`

## Spacing Rules
- Screen padding: 24px
- Card padding: 16px
- Element spacing: 16px (standard), 8px (tight)
- Button height: 64px (primary), 48px (secondary)

## Typography
- Font: Press Start 2P (Google Fonts) — pixel bitmap font
- Stitch proxy: Space Grotesk
- Title: 16px, bold, uppercase
- Body: 12-14px, regular
- Label: 10px

## Component Patterns
- **Player Card:** Avatar (64px) with league-colored ring + name/class/XP bar + level badge — used on Home and Profile screens
- **Stat Cards:** Equal-width cards with colored value text and muted label — teal for wins, red for losses, gold for league
- **Swipe Card:** Full-height card with photo area (60%), info section below with class badge and win/loss stats
- **Chat Bubbles:** Left-aligned (#16213E) for incoming, right-aligned (#FF6B6B) for outgoing, timestamps below groups
- **Health Bars:** Rounded, full-width, color-coded by health percentage (green > 50%, orange > 25%, red < 25%)
- **Mana Bar:** Thin blue bar with numeric readout, positioned below health bar
- **League Tabs:** Horizontal scrollable tab bar, each tab tinted to match league color
- **Leaderboard Rows:** Surface-colored cards, rank number + avatar + name + class + level/XP, crown/medal for top 3
- **Action List Tiles:** Icon + text + chevron, surface background, used for navigation (Leaderboard, Battle History, etc.)
