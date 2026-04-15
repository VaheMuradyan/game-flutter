import '../services/audio_service.dart';

/// Thin facade kept for backwards compatibility with existing call sites.
/// New code should call [AudioService.instance] directly.
class BattleAudio {
  static Future<void> preload() => AudioService.instance.init();

  static void battleStart() {
    AudioService.instance.startBattle();
  }

  static void troopDeploy() => AudioService.instance.troopDeploy();
  static void spellCast() => AudioService.instance.spellCast();
  static void towerHit() => AudioService.instance.towerHit();
  static void towerDestroyed() => AudioService.instance.towerDestroyed();
  static void countdownTick() => AudioService.instance.countdownTick();
  static void victory() =>
      AudioService.instance.endBattle(victory: true);
  static void defeat() =>
      AudioService.instance.endBattle(victory: false);
  static void matchFound() => AudioService.instance.matchFound();
}
