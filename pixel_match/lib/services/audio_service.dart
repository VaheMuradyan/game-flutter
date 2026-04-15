import 'dart:async';
import 'package:flame_audio/flame_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BattleAudioState { idle, calm, intense, ended }

/// Adaptive battle audio: two-layer cross-faded music + SFX, gated by
/// user toggles persisted in SharedPreferences. All playback paths
/// swallow exceptions so missing assets never crash a battle.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const _kMusicPref = 'audio_music_enabled';
  static const _kSfxPref = 'audio_sfx_enabled';

  static const _calmMaxVolume = 0.45;
  static const _intenseMaxVolume = 0.60;
  static const _crossfadeMs = 1200;
  static const _stepMs = 60;

  static const _sfxFiles = <String>[
    'troop_deploy.mp3',
    'troop_march.mp3',
    'tower_hit_1.mp3',
    'tower_hit_2.mp3',
    'tower_destroyed.mp3',
    'victory.mp3',
    'defeat.mp3',
    'countdown_tick.mp3',
    'spell_cast.mp3',
    'match_found.mp3',
  ];
  static const _musicFiles = <String>[
    'music_calm.mp3',
    'music_intense.mp3',
  ];

  bool _initialized = false;
  bool _musicEnabled = true;
  bool _sfxEnabled = true;

  AudioPlayer? _calmPlayer;
  AudioPlayer? _intensePlayer;
  Timer? _fadeTimer;
  BattleAudioState _state = BattleAudioState.idle;
  int _hitVariant = 0;

  bool get musicEnabled => _musicEnabled;
  bool get sfxEnabled => _sfxEnabled;
  BattleAudioState get state => _state;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _musicEnabled = prefs.getBool(_kMusicPref) ?? true;
    _sfxEnabled = prefs.getBool(_kSfxPref) ?? true;
    try {
      await FlameAudio.audioCache.loadAll([..._sfxFiles, ..._musicFiles]);
    } catch (_) {}
  }

  Future<void> setMusicEnabled(bool value) async {
    _musicEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMusicPref, value);
    if (!value) {
      await _stopMusic();
    } else if (_state == BattleAudioState.calm ||
        _state == BattleAudioState.intense) {
      await _startMusic();
      _applyTargetVolumes();
    }
  }

  Future<void> setSfxEnabled(bool value) async {
    _sfxEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSfxPref, value);
  }

  Future<void> startBattle() async {
    await init();
    _hitVariant = 0;
    _state = BattleAudioState.calm;
    if (_musicEnabled) await _startMusic();
  }

  Future<void> _startMusic() async {
    try {
      _calmPlayer ??= await FlameAudio.loop('music_calm.mp3', volume: 0);
      _intensePlayer ??=
          await FlameAudio.loop('music_intense.mp3', volume: 0);
      await _calmPlayer?.setVolume(_calmMaxVolume);
      await _intensePlayer?.setVolume(0);
    } catch (_) {}
  }

  Future<void> _stopMusic() async {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    try {
      await _calmPlayer?.stop();
      await _intensePlayer?.stop();
      await _calmPlayer?.dispose();
      await _intensePlayer?.dispose();
    } catch (_) {}
    _calmPlayer = null;
    _intensePlayer = null;
  }

  /// Call from the game loop with current HP fractions (0..1).
  /// Triggers the intense layer the first time either tower drops to 50% HP.
  void escalateIfNeeded(double playerHpFraction, double enemyHpFraction) {
    if (_state != BattleAudioState.calm) return;
    if (playerHpFraction <= 0.5 || enemyHpFraction <= 0.5) {
      _transitionToIntense();
    }
  }

  void _transitionToIntense() {
    _state = BattleAudioState.intense;
    if (!_musicEnabled) return;
    _crossFade(toIntense: true);
  }

  void _crossFade({required bool toIntense}) {
    final calm = _calmPlayer;
    final intense = _intensePlayer;
    if (calm == null || intense == null) return;

    _fadeTimer?.cancel();
    final steps = (_crossfadeMs / _stepMs).round();
    var step = 0;
    _fadeTimer =
        Timer.periodic(const Duration(milliseconds: _stepMs), (timer) {
      step++;
      final t = (step / steps).clamp(0.0, 1.0);
      final calmVol = (toIntense ? (1.0 - t) : t) * _calmMaxVolume;
      final intenseVol = (toIntense ? t : (1.0 - t)) * _intenseMaxVolume;
      try {
        calm.setVolume(calmVol);
        intense.setVolume(intenseVol);
      } catch (_) {}
      if (step >= steps) {
        timer.cancel();
        _fadeTimer = null;
      }
    });
  }

  void _applyTargetVolumes() {
    final calm = _calmPlayer;
    final intense = _intensePlayer;
    if (calm == null || intense == null) return;
    try {
      if (_state == BattleAudioState.calm) {
        calm.setVolume(_calmMaxVolume);
        intense.setVolume(0);
      } else if (_state == BattleAudioState.intense) {
        calm.setVolume(0);
        intense.setVolume(_intenseMaxVolume);
      }
    } catch (_) {}
  }

  Future<void> endBattle({required bool victory}) async {
    _state = BattleAudioState.ended;
    await _stopMusic();
    _safePlay(victory ? 'victory.mp3' : 'defeat.mp3');
  }

  Future<void> reset() async {
    await _stopMusic();
    _state = BattleAudioState.idle;
  }

  void _safePlay(String file, {double volume = 1.0}) {
    if (!_sfxEnabled) return;
    try {
      FlameAudio.play(file, volume: volume);
    } catch (_) {}
  }

  void troopDeploy() => _safePlay('troop_deploy.mp3', volume: 0.7);
  void troopMarch() => _safePlay('troop_march.mp3', volume: 0.4);
  void towerHit() {
    final variant =
        (_hitVariant++ % 2) == 0 ? 'tower_hit_1.mp3' : 'tower_hit_2.mp3';
    _safePlay(variant, volume: 0.8);
  }

  void towerDestroyed() => _safePlay('tower_destroyed.mp3');
  void countdownTick() => _safePlay('countdown_tick.mp3', volume: 0.6);
  void spellCast() => _safePlay('spell_cast.mp3', volume: 0.8);
  void matchFound() => _safePlay('match_found.mp3');
}
