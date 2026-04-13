import 'package:flame_audio/flame_audio.dart';

/// Audio manager for battle sound effects.
///
/// All play methods swallow exceptions so that missing asset files
/// don't crash the game during development.
class BattleAudio {
  static bool _loaded = false;

  static const _files = [
    'battle_start.mp3',
    'troop_deploy.mp3',
    'spell_cast.mp3',
    'tower_hit.mp3',
    'victory.mp3',
    'defeat.mp3',
    'match_found.mp3',
  ];

  static Future<void> preload() async {
    if (_loaded) return;
    _loaded = true;
    try {
      await FlameAudio.audioCache.loadAll(_files);
    } catch (_) {
      // Audio assets not yet present — fail silently.
    }
  }

  static void _safePlay(String file) {
    try {
      FlameAudio.play(file);
    } catch (_) {}
  }

  static void battleStart() => _safePlay('battle_start.mp3');
  static void troopDeploy() => _safePlay('troop_deploy.mp3');
  static void spellCast()   => _safePlay('spell_cast.mp3');
  static void towerHit()    => _safePlay('tower_hit.mp3');
  static void victory()     => _safePlay('victory.mp3');
  static void defeat()      => _safePlay('defeat.mp3');
  static void matchFound()  => _safePlay('match_found.mp3');
}
