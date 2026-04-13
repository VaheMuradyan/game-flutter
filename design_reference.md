# PixelMatch Design Reference

Generated via Google Stitch MCP on 2026-04-13.

## Stitch Project
- Project ID: `9737804382768018004`
- Design System Asset ID: `8298726932259888127`
- Design System Name: `PixelMatch Dark`
- Color Mode: DARK
- Headline/Body Font: Space Grotesk (closest Stitch match to Press Start 2P)
- Custom Primary: `#FF6B6B`
- Roundness: ROUND_FOUR

## Adopted Screen Designs

| Screen | Screen ID | Variant | Key Design Notes |
|--------|-----------|---------|------------------|
| Welcome / Login | `57dcdc85d8834b2d908b073ce60b7a41` | Original | Crossed-swords logo, email/password on dark surface, full-width red SIGN UP button, pixel grid background texture |
| Class Selection | `6a67c2e9353a405893ee7dfd993ac78b` | Original | 5 vertical class cards (Warrior/Mage/Archer/Rogue/Healer), selected state uses `#FF6B6B` border, CONTINUE CTA at bottom |
| Home / Arena | `d1f544347d004ca2a8c508a527494574` | Variant B (CTA-centered, `ab09cc4559554beeaca2fdfcbb52d4d5`) | FIND BATTLE elevated as dominant central CTA; compact player card above; stats + quick links stacked below |
| Match Browser | `fc17120ffa254285b106c39c5e01f163` | Original | Card ~85% of viewport; class badge + league ring + WR stats stacked below photo; swipe counter above bottom nav |
| Battle HUD | `faab09af2d4d48eb86441a1ac180057b` | Variant B (Gritty Arcade bottom panel, `ce5e2fc66c464f54bd885032eb28421d`) | Player health/mana/spell consolidated into one bottom-docked panel; enemy bar + timer at top |
| Profile | `fa9d7fb4fc334c59a60a95af61740625` | Original | 96px avatar with gold ring, centered name/class, XP bar, 2x2 stats grid, list tiles, red-outline Sign Out |
| Chat | `bb94a02671f04e62ad96f92fe0079714` | Original | Incoming bubbles `#16213E`, outgoing `#FF6B6B`, horizontal emote row + text input + teal send button |
| Leaderboard | `e5c166ad004b46e397fddac9140af847` | Original | League-colored tab bar, top-3 crown/medal icons, highlighted current-user row |

## Welcome Screen Variants
| Variant | Screen ID | Notes |
|---------|-----------|-------|
| A | `8a7849cf55c14bb7b6b7dba91f98b107` | Player-readiness — wider vertical spacing above form, social login placed directly below primary CTA |
| B | `eb4cee7503c7475a827707d0bc9f6e76` | Synthwave palette — neon purple `#E000FF` + electric blue `#00AFFF` (rejected: drifts from brand) |
| C | `939ecf603f734d6b8fbc4564b4e19945` | Gritty arcade — desaturated red `#C2524D`, bordered tactile inputs |

## Home Screen Variants
| Variant | Screen ID | Notes |
|---------|-----------|-------|
| A | `7274d99399714af895fa1d77cd595a95` | Stats-first flow (player card → stats → CTA → quick links) |
| B | `ab09cc4559554beeaca2fdfcbb52d4d5` | **ADOPTED** — CTA-centered, compact player card above, stats/quick links stacked below |
| C | `7c7d2005ec4a43888489388ebeb42608` | Dashboard hub — player card absorbs quick links into one top section |

## Battle HUD Variants
| Variant | Screen ID | Notes |
|---------|-----------|-------|
| A | `80ec7b38275b4efca84b9d830ba3fd91` | Deep-space retro — vertical side HUD bars, electric blue player / orange enemy |
| B | `ce5e2fc66c464f54bd885032eb28421d` | **ADOPTED** — unified bottom-docked HUD panel (health + mana + spell), gritty-arcade palette |
| C | `b4ac8f563f8c428db822749305919aa3` | Neo-noir tech-block — angular panels, neon-pink enemy, deep-teal player |

## Color Palette (Final — matches `pixel_match/lib/config/theme.dart`)
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
- Card radius: 8px (Stitch ROUND_FOUR)

## Typography
- Font: Press Start 2P (Google Fonts) — pixel bitmap font
- Stitch proxy: Space Grotesk
- Title: 16px, bold, uppercase
- Body: 12–14px, regular
- Label: 10px

## Component Patterns
- **Player Card:** Avatar (64px) with league-colored ring + name/class/XP bar + level badge — used on Home and Profile
- **Stat Cards:** Equal-width cards with colored value text and muted label — teal for wins, red for losses, gold for league
- **Swipe Card:** Full-height card with photo area (~60%), info section below with class badge and win/loss stats
- **Chat Bubbles:** Left-aligned `#16213E` incoming, right-aligned `#FF6B6B` outgoing, timestamps below groups
- **Health Bars:** Rounded full-width bars, color-coded by percentage (green > 50%, orange > 25%, red < 25%)
- **Mana Bar:** Thin blue bar with numeric readout, positioned adjacent to health bar
- **Unified Bottom HUD Panel:** (from Battle HUD Variant B) — grouping health/mana/spell reduces visual clutter during gameplay
- **League Tabs:** Horizontal tab bar, each tab tinted to match league color
- **Leaderboard Rows:** Surface-colored cards, rank + avatar + name + class badge + level/XP, crown/medal for top 3
- **Action List Tiles:** Icon + text + chevron, surface background (Leaderboard, Battle History, Edit Display Name, etc.)

## Notes for Flutter Code Updates (Phase 14+)
- When reworking `home_screen.dart`, adopt the CTA-centered Home Variant B layout.
- When reworking `battle_screen.dart`, consolidate the player HUD into a single bottom panel matching Battle HUD Variant B.
- No other screens require structural changes — originals align with the current Flutter implementation.
- Typography stays on Press Start 2P; Stitch's Space Grotesk is only a preview stand-in.
