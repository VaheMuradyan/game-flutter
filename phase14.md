# Phase 14 — Game Art & Asset Pipeline

## Goal
Replace all programmatic canvas drawing with actual sprite assets. Create pixel-art sprites for characters, towers, troops, and spells. Add a background image for the arena. Integrate audio effects for battles. When this phase is complete, the game has real visual art and sound instead of colored rectangles and circles.

> **NO BACKEND CHANGES.** This phase is purely Flutter/Flame asset work.

## Prerequisites
Phase 13 complete: design system established providing color palette and art direction.

---

## 1. Asset Manifest

Define every asset needed. All sprites should use a consistent pixel-art style with the palette from `class_colors.dart` and the design system.

### Sprites (`assets/sprites/`) — 32×32 PNG, transparent background

| File | Description |
|------|-------------|
| `tower_player.png` | Player tower — castle/fort, teal-blue tone |
| `tower_enemy.png` | Enemy tower — castle/fort, red tone |
| `troop_warrior.png` | Warrior troop — sword & shield, blue |
| `troop_mage.png` | Mage troop — staff & hat, purple |
| `troop_archer.png` | Archer troop — bow & quiver, green |
| `troop_rogue.png` | Rogue troop — dual daggers, dark gray |
| `troop_healer.png` | Healer troop — staff & cross, gold |
| `spell_fireball.png` | Fireball spell effect, orange/red glow |
| `spell_heal.png` | Heal spell effect, green/gold glow |
| `spell_lightning.png` | Lightning spell effect, blue/white |

### Images (`assets/images/`) — various sizes

| File | Size | Description |
|------|------|-------------|
| `arena_bg.png` | 360×640 | Battle arena background (dark grid, lane divider) |
| `logo.png` | 256×256 | PixelMatch logo for welcome screen |
| `class_warrior.png` | 128×128 | Warrior class art for selection screen |
| `class_mage.png` | 128×128 | Mage class art for selection screen |
| `class_archer.png` | 128×128 | Archer class art for selection screen |
| `class_rogue.png` | 128×128 | Rogue class art for selection screen |
| `class_healer.png` | 128×128 | Healer class art for selection screen |

### Audio (`assets/audio/`)

| File | Duration | Description |
|------|----------|-------------|
| `battle_start.mp3` | 1–2s | Fanfare when battle begins |
| `troop_deploy.mp3` | 0.5s | Short pop/whoosh on troop spawn |
| `spell_cast.mp3` | 0.5s | Magical swish for spell launch |
| `tower_hit.mp3` | 0.3s | Impact sound when tower takes damage |
| `victory.mp3` | 2–3s | Victory jingle |
| `defeat.mp3` | 2–3s | Defeat sound |
| `match_found.mp3` | 1s | Chime when a dating match is found |

---

## 2. Art Creation Guidelines

Since Google Stitch does not generate pixel-art sprites, use one of these approaches:

### Option A: Manual Pixel Art (Recommended for quality)
- **Tools:** Aseprite ($20), Piskel (free, web-based), or LibreSprite (free)
- **Canvas size:** 32×32 for game sprites, 128×128 for class selection art
- **Palette:** Use the 6 class colors from `lib/game/class_colors.dart`:
  ```
  Warrior: #3498DB (blue)
  Mage:    #9B59B6 (purple)
  Archer:  #2ECC71 (green)
  Rogue:   #95A5A6 (gray)
  Healer:  #F1C40F (gold)
  Enemy:   #E74C3C (red)
  ```
- **Style guide:** 1-2px outlines, limited shading (2-3 tones per color), transparent backgrounds
- **Export:** PNG with transparency

### Option B: AI Image Generation
- Use an image generation tool with prompts like:
  ```
  "32x32 pixel art warrior character holding sword and shield, 
   blue color scheme (#3498DB), transparent background, 
   retro SNES RPG style, no anti-aliasing"
  ```
- Post-process in Piskel/Aseprite to clean up edges and match palette
- Ensure consistent style across all sprites by using the same seed/style

### Option C: Free Asset Packs
- Search itch.io for "pixel art RPG character sprites" (many free CC0 packs)
- Recolor to match the PixelMatch palette
- Ensure license allows commercial use

---

## 3. Update `pubspec.yaml` — Add `flame_audio`

```yaml
dependencies:
  # ... existing deps ...
  flame_audio: ^2.1.0

# Verify asset paths are listed:
flutter:
  assets:
    - assets/images/
    - assets/sprites/
    - assets/audio/
    - assets/fonts/
```

Run `flutter pub get` after adding.

---

## 4. Refactor Tower Component — `lib/game/components/tower.dart`

Replace `canvas.drawRect()` with `SpriteComponent`.

```dart
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'dart:ui';

class Tower extends SpriteComponent with HasGameReference {
  final bool isPlayer;
  final Color color;
  int health;
  final int maxHealth;

  Tower({required this.isPlayer, required this.color, this.maxHealth = 1000})
      : health = maxHealth;

  bool get isDestroyed => health <= 0;

  @override
  Future<void> onLoad() async {
    final imageName = isPlayer ? 'tower_player.png' : 'tower_enemy.png';
    sprite = await Sprite.load(imageName);
    size = Vector2(48, 64);
    anchor = Anchor.center;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Health bar above the tower
    const barWidth = 48.0;
    const barHeight = 6.0;
    final barX = 0.0;
    final barY = isPlayer ? size.y + 4 : -barHeight - 4;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(barX, barY, barWidth, barHeight),
      Paint()..color = const Color(0xFF333333),
    );

    // Fill
    final ratio = health / maxHealth;
    final fillColor = ratio > 0.5
        ? const Color(0xFF2ECC71)
        : ratio > 0.25
            ? const Color(0xFFF39C12)
            : const Color(0xFFE74C3C);
    canvas.drawRect(
      Rect.fromLTWH(barX, barY, barWidth * ratio, barHeight),
      Paint()..color = fillColor,
    );
  }
}
```

---

## 5. Refactor Troop Component — `lib/game/components/troop.dart`

Replace circle/rect drawing with a sprite.

```dart
import 'package:flame/components.dart';
import 'dart:ui';
import 'tower.dart';

class Troop extends SpriteComponent with HasGameReference {
  final bool isPlayer;
  final Color color;
  final String characterClass;
  Tower? targetTower;
  final int damage;
  final double speed;
  bool _hasHit = false;

  Troop({
    required this.isPlayer,
    required this.color,
    this.characterClass = 'Warrior',
    this.damage = 50,
    this.speed = 60.0,
  });

  @override
  Future<void> onLoad() async {
    // Load class-specific sprite, fallback to warrior
    final spriteName = isPlayer
        ? 'troop_${characterClass.toLowerCase()}.png'
        : 'troop_warrior.png'; // enemies use warrior sprite
    try {
      sprite = await Sprite.load(spriteName);
    } catch (_) {
      sprite = await Sprite.load('troop_warrior.png');
    }
    size = Vector2(24, 24);
    anchor = Anchor.center;

    // Flip enemy troops to face downward
    if (!isPlayer) {
      flipVertically();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hasHit || targetTower == null) return;

    final direction = (targetTower!.position - position).normalized();
    position += direction * speed * dt;

    if (position.distanceTo(targetTower!.position) < 20) {
      _hasHit = true;
      targetTower!.health -= damage;
      if (targetTower!.health < 0) targetTower!.health = 0;
      removeFromParent();
    }
  }
}
```

---

## 6. Refactor Arena Component — `lib/game/components/arena.dart`

Replace the solid color + grid drawing with a background image.

```dart
import 'package:flame/components.dart';

class Arena extends SpriteComponent with HasGameReference {
  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('arena_bg.png');
    size = gameRef.size;
    position = Vector2.zero();
    priority = -1; // render behind everything
  }
}
```

Note: The `arena_bg.png` image should be `assets/images/arena_bg.png`. Make sure to load it from the images directory. If using Flame's default asset loading, images go in `assets/images/`.

---

## 7. Update Spell Component — `lib/game/components/spell.dart`

Add sprite-based rendering with glow effect fallback.

```dart
import 'package:flame/components.dart';
import 'dart:ui';

class Spell extends SpriteComponent with HasGameReference {
  final Vector2 target;
  final Color color;
  final int damage;
  final double speed;
  final void Function(Vector2 position, int damage) onImpact;
  bool _exploded = false;

  Spell({
    required this.target,
    required this.color,
    this.damage = 100,
    this.speed = 200.0,
    required this.onImpact,
  });

  @override
  Future<void> onLoad() async {
    try {
      sprite = await Sprite.load('spell_fireball.png');
    } catch (_) {
      // Fallback: no sprite, render() will draw a circle
    }
    size = Vector2(16, 16);
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_exploded) return;
    final direction = (target - position).normalized();
    position += direction * speed * dt;
    if (position.distanceTo(target) < 8) {
      _exploded = true;
      onImpact(position, damage);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      super.render(canvas);
    } else {
      // Fallback circle rendering
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x / 2,
        Paint()..color = color,
      );
    }
    // Glow effect
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2 + 4,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }
}
```

---

## 8. Add Audio — `lib/game/battle_audio.dart`

Create a simple audio manager using `flame_audio`.

```dart
import 'package:flame_audio/flame_audio.dart';

class BattleAudio {
  static bool _loaded = false;

  static Future<void> preload() async {
    if (_loaded) return;
    await FlameAudio.audioCache.loadAll([
      'battle_start.mp3',
      'troop_deploy.mp3',
      'spell_cast.mp3',
      'tower_hit.mp3',
      'victory.mp3',
      'defeat.mp3',
    ]);
    _loaded = true;
  }

  static void battleStart() => FlameAudio.play('battle_start.mp3');
  static void troopDeploy() => FlameAudio.play('troop_deploy.mp3');
  static void spellCast() => FlameAudio.play('spell_cast.mp3');
  static void towerHit() => FlameAudio.play('tower_hit.mp3');
  static void victory() => FlameAudio.play('victory.mp3');
  static void defeat() => FlameAudio.play('defeat.mp3');
}
```

---

## 9. Integrate Audio into Game — `lib/game/pixel_match_game.dart`

Add audio triggers at key moments.

```dart
import 'battle_audio.dart';

class PixelMatchGame extends FlameGame with TapCallbacks {
  // ... existing code ...

  @override
  Future<void> onLoad() async {
    await BattleAudio.preload();
    // ... existing onLoad code ...
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (event.localPosition.y < size.y / 2 && mana >= troopCost) {
      mana -= troopCost;
      final x = event.localPosition.x;
      final y = size.y / 2 + 20;
      _spawnPlayerTroop(x, y);
      BattleAudio.troopDeploy();  // NEW
      if (isMultiplayer) onTroopDeployed?.call(x, y);
    }
  }

  void castSpell() {
    if (mana >= spellCost) {
      mana -= spellCost;
      BattleAudio.spellCast();  // NEW
      // ... existing spell code ...
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // ... existing update code ...

    if (enemyTower.isDestroyed) {
      BattleAudio.victory();  // NEW
      onBattleEnd?.call(true);
      pauseEngine();
    } else if (playerTower.isDestroyed) {
      BattleAudio.defeat();  // NEW
      onBattleEnd?.call(false);
      pauseEngine();
    }
  }
}
```

Also trigger `BattleAudio.battleStart()` from the battle screen when the game begins.

---

## 10. Update Class Selection Screen — Replace Emoji Icons

Replace the emoji strings in `lib/screens/onboarding/class_selection_screen.dart` with the 128×128 class art images.

```dart
// Replace the class data that currently uses emoji:
//   {'name': 'Warrior', 'icon': '🛡️', ...}
// With image-based cards:

static const _classes = [
  {'name': 'Warrior', 'image': 'assets/images/class_warrior.png', 'desc': 'Strong and steadfast'},
  {'name': 'Mage', 'image': 'assets/images/class_mage.png', 'desc': 'Arcane power unleashed'},
  {'name': 'Archer', 'image': 'assets/images/class_archer.png', 'desc': 'Precise and deadly'},
  {'name': 'Rogue', 'image': 'assets/images/class_rogue.png', 'desc': 'Quick and cunning'},
  {'name': 'Healer', 'image': 'assets/images/class_healer.png', 'desc': 'Support and sustain'},
];

// In the card widget, replace the emoji Text with:
Image.asset(
  classData['image']!,
  width: 64,
  height: 64,
  filterQuality: FilterQuality.none, // Keep pixel art crisp
),
```

**Important:** Use `FilterQuality.none` on all pixel-art `Image` widgets to prevent blurring from bilinear filtering.

---

## 11. Update Welcome Screen — Add Logo

Add the PixelMatch logo to the welcome screen.

```dart
// In lib/screens/onboarding/welcome_screen.dart, replace the icon/title area:
Image.asset(
  'assets/images/logo.png',
  width: 128,
  height: 128,
  filterQuality: FilterQuality.none,
),
```

---

## 12. Troop Class Integration — `pixel_match_game.dart`

Update troop spawning to pass the player's character class so the correct sprite loads.

```dart
void _spawnPlayerTroop(double x, double y) {
  final troop = Troop(
    isPlayer: true,
    color: ClassColors.forClass(playerClass),
    characterClass: playerClass,  // NEW — loads class-specific sprite
  )
    ..position = Vector2(x, y)
    ..targetTower = enemyTower;
  add(troop);
}
```

---

## 13. Verification Checklist

### Assets Exist
- [ ] All 10 sprite files exist in `assets/sprites/`
- [ ] All 7 image files exist in `assets/images/`
- [ ] All 7 audio files exist in `assets/audio/`
- [ ] `pubspec.yaml` declares all asset directories

### Sprites Load
- [ ] Player tower renders as sprite (not colored rectangle)
- [ ] Enemy tower renders as sprite
- [ ] Player troop renders as class-specific sprite
- [ ] Enemy troop renders as sprite
- [ ] Spell renders as sprite with glow effect

### Arena
- [ ] Arena background image loads and fills the screen
- [ ] Game components render on top of background

### Audio
- [ ] Battle start sound plays when match begins
- [ ] Troop deploy sound plays on tap
- [ ] Spell cast sound plays on spell button
- [ ] Victory/defeat sounds play at battle end

### Class Selection
- [ ] 5 class cards show 128×128 character art (not emoji)
- [ ] Pixel art is crisp (not blurry) via `FilterQuality.none`

### Welcome Screen
- [ ] PixelMatch logo displayed
- [ ] Logo is crisp pixel art

### Gameplay
- [ ] Single-player battle works with sprites
- [ ] Multiplayer battle works with sprites
- [ ] Performance is acceptable (no frame drops from sprite loading)

---

## What Phase 15 Expects
A visually polished game with real sprites, backgrounds, and audio. The app looks and sounds like a finished game, ready for premium features and testing.

## New Files Created in This Phase
```
pixel_match/
├── lib/game/battle_audio.dart              (audio manager)
├── assets/sprites/
│   ├── tower_player.png, tower_enemy.png
│   ├── troop_warrior.png, troop_mage.png, troop_archer.png
│   ├── troop_rogue.png, troop_healer.png
│   ├── spell_fireball.png, spell_heal.png, spell_lightning.png
├── assets/images/
│   ├── arena_bg.png, logo.png
│   ├── class_warrior.png, class_mage.png, class_archer.png
│   ├── class_rogue.png, class_healer.png
└── assets/audio/
    ├── battle_start.mp3, troop_deploy.mp3, spell_cast.mp3
    ├── tower_hit.mp3, victory.mp3, defeat.mp3, match_found.mp3
```

## Files Modified
```
pixel_match/
├── pubspec.yaml                                    (add flame_audio)
├── lib/game/components/tower.dart                  (SpriteComponent)
├── lib/game/components/troop.dart                  (SpriteComponent + class param)
├── lib/game/components/arena.dart                  (SpriteComponent)
├── lib/game/components/spell.dart                  (sprite + fallback)
├── lib/game/pixel_match_game.dart                  (audio triggers, class param)
├── lib/screens/onboarding/class_selection_screen.dart (Image.asset)
└── lib/screens/onboarding/welcome_screen.dart      (logo)
```
