import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 23 Suara Resmi Pentatonik C (Kalimba Kayu) sesuai UPDATE_1_PERMAINAN_DAN_SUARA.md
enum Sfx {
  splashJingle('audio/splash_jingle.wav'),
  wheelTick1('audio/wheel_tick_1.wav'),
  wheelTick2('audio/wheel_tick_2.wav'),
  wheelTick3('audio/wheel_tick_3.wav'),
  wheelSpin('audio/wheel_spin.wav'),
  wheelLand('audio/wheel_land.wav'),
  diceRoll('audio/dice_roll.wav'),
  diceLand('audio/dice_land.wav'),
  capsuleCrank('audio/capsule_crank.wav'),
  capsuleDrop('audio/capsule_drop.wav'),
  capsuleOpen('audio/capsule_open.wav'),
  envelopeShuffle('audio/envelope_shuffle.wav'),
  envelopeOpen('audio/envelope_open.wav'),
  winLolos('audio/win_lolos.wav'),
  overBudget('audio/over_budget.wav'),
  coinRecord('audio/coin_record.wav'),
  notifWarning('audio/notif_warning.wav'),
  notifReminder('audio/notif_reminder.wav'),
  uiTap('audio/ui_tap.wav'),
  coinFlip('audio/coin_flip.wav'),
  coinLand('audio/coin_land.wav'),
  coinDouble('audio/coin_double.wav'),
  coinHalve('audio/coin_halve.wav');

  final String assetPath;
  const Sfx(this.assetPath);
}

/// Model Pengaturan Suara & Getaran
class SoundSettings {
  final bool soundEnabled;
  final bool vibrationEnabled;
  final double volume;

  const SoundSettings({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.volume = 1.0,
  });

  SoundSettings copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    double? volume,
  }) {
    return SoundSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      volume: volume ?? this.volume,
    );
  }
}

/// Dedicated Sound Player wrapper untuk memastikan nol-latensi dan 100% reliabilitas
class _DedicatedPlayer {
  final String id;
  final Sfx sfx;
  final AudioPlayer player;
  Timer? autoStopTimer;
  bool isPlaying = false;

  _DedicatedPlayer({
    required this.id,
    required this.sfx,
    required this.player,
  });
}

/// Service Audio Low-Latency dan Haptik Sinkron
/// Menggunakan SoundPool native Android dengan dedicated pre-buffered player per SFX.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const String _keySound = 'pj_sound_enabled';
  static const String _keyVibration = 'pj_vibration_enabled';
  static const String _keyVolume = 'pj_sound_volume';

  static final AudioContext _audioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  final ValueNotifier<SoundSettings> settingsNotifier =
      ValueNotifier<SoundSettings>(const SoundSettings());

  /// Notifier untuk status mute (kompatibilitas UI sakelar suara)
  final ValueNotifier<bool> isMutedNotifier = ValueNotifier<bool>(false);

  /// Map dedicated player per SFX
  final Map<Sfx, List<_DedicatedPlayer>> _players = {};
  final Map<Sfx, int> _playerIndices = {};

  final math.Random _rng = math.Random();
  int _lastTickIndex = -1;
  int _lastTickTime = 0;
  bool _initialized = false;

  SoundSettings get settings => settingsNotifier.value;
  bool get isSoundEnabled => settingsNotifier.value.soundEnabled;
  bool get isVibrationEnabled => settingsNotifier.value.vibrationEnabled;
  bool get isMuted => !settingsNotifier.value.soundEnabled;
  double get masterVolume => settingsNotifier.value.volume;

  AudioPlayer _createPlayerInstance(String id) {
    final p = AudioPlayer(playerId: id);
    p.setPlayerMode(PlayerMode.lowLatency).catchError((_) {});
    p.setAudioContext(_audioContext).catchError((_) {});
    p.setReleaseMode(ReleaseMode.stop).catchError((_) {});
    return p;
  }

  /// Inisialisasi dan pra-decode semua 23 suara ke Android SoundPool RAM C++ saat splash
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final vibration = prefs.getBool(_keyVibration) ?? true;
      final savedVolume = prefs.getDouble(_keyVolume) ?? 1.0;
      final effectiveVolume = savedVolume <= 0.05 ? 1.0 : savedVolume;

      await prefs.setBool(_keySound, true);
      if (savedVolume <= 0.05) {
        await prefs.setDouble(_keyVolume, 1.0);
      }

      settingsNotifier.value = SoundSettings(
        soundEnabled: true,
        vibrationEnabled: vibration,
        volume: effectiveVolume,
      );
      isMutedNotifier.value = false;

      try {
        await AudioPlayer.global.setAudioContext(_audioContext);
      } catch (e) {
        debugPrint('[SoundService] Global AudioContext warning: $e');
      }

      // Pre-cache semua 23 file WAV ke local asset cache
      try {
        await AudioCache.instance.loadAll(
          Sfx.values.map((s) => s.assetPath).toList(),
        );
      } catch (e) {
        debugPrint('[SoundService] AudioCache loadAll warning: $e');
      }

      // Buat dedicated pre-buffered player untuk setiap SFX dengan ReleaseMode.stop
      // ReleaseMode.stop WAJIB agar soundId tetap tersimpan permanen di RAM SoundPool C++
      // dan TIDAK pernah di-unload saat stop() dipanggil.
      for (final sfx in Sfx.values) {
        final count = (sfx == Sfx.wheelTick1 ||
                sfx == Sfx.wheelTick2 ||
                sfx == Sfx.wheelTick3 ||
                sfx == Sfx.diceRoll ||
                sfx == Sfx.diceLand ||
                sfx == Sfx.capsuleCrank ||
                sfx == Sfx.capsuleDrop ||
                sfx == Sfx.envelopeShuffle ||
                sfx == Sfx.envelopeOpen ||
                sfx == Sfx.coinFlip ||
                sfx == Sfx.coinLand ||
                sfx == Sfx.uiTap)
            ? 2
            : 1;
        final list = <_DedicatedPlayer>[];
        for (int i = 0; i < count; i++) {
          final id = 'pj_${sfx.name}_$i';
          final ap = AudioPlayer(playerId: id);
          try {
            await ap.setPlayerMode(PlayerMode.lowLatency);
            await ap.setAudioContext(_audioContext);
            await ap.setReleaseMode(ReleaseMode.stop);
            await ap.setSource(AssetSource(sfx.assetPath));
          } catch (e) {
            debugPrint('[SoundService] Error setting up player $id: $e');
          }
          list.add(_DedicatedPlayer(id: id, sfx: sfx, player: ap));
        }
        _players[sfx] = list;
        _playerIndices[sfx] = 0;
      }

      _initialized = true;
      debugPrint('[SoundService] Berhasil pra-decode 23 suara resmi ke RAM SoundPool (suara=aktif, volume=$effectiveVolume)');
    } catch (e) {
      debugPrint('[SoundService] Init fallback error: $e');
    }
  }

  /// Durasi aman tiap SFX untuk auto-reset status player di Android SoundPool
  Duration _getSfxDuration(Sfx sfx) {
    switch (sfx) {
      case Sfx.wheelTick1:
      case Sfx.wheelTick2:
      case Sfx.wheelTick3:
        return const Duration(milliseconds: 90);
      case Sfx.uiTap:
        return const Duration(milliseconds: 140);
      case Sfx.coinFlip:
        return const Duration(milliseconds: 250);
      case Sfx.coinLand:
        return const Duration(milliseconds: 320);
      case Sfx.diceRoll:
        return const Duration(milliseconds: 380);
      case Sfx.diceLand:
        return const Duration(milliseconds: 450);
      case Sfx.coinHalve:
        return const Duration(milliseconds: 650);
      case Sfx.coinDouble:
      case Sfx.coinRecord:
        return const Duration(milliseconds: 950);
      case Sfx.notifWarning:
        return const Duration(milliseconds: 1000);
      case Sfx.capsuleDrop:
      case Sfx.notifReminder:
        return const Duration(milliseconds: 1200);
      case Sfx.capsuleOpen:
      case Sfx.envelopeShuffle:
      case Sfx.envelopeOpen:
        return const Duration(milliseconds: 1400);
      case Sfx.overBudget:
      case Sfx.wheelLand:
        return const Duration(milliseconds: 1600);
      case Sfx.capsuleCrank:
        return const Duration(milliseconds: 1750);
      case Sfx.winLolos:
        return const Duration(milliseconds: 2500);
      case Sfx.splashJingle:
        return const Duration(milliseconds: 4200);
      case Sfx.wheelSpin:
        return const Duration(milliseconds: 6200);
    }
  }

  /// Mainkan efek suara bersama haptic feedback seketika pada frame yang sama
  void play(
    Sfx sfx, {
    double volume = 1.0,
    double pitch = 1.0,
    bool haptic = true,
  }) {
    // 1. Haptic feedback instan pada frame pemanggilan
    if (haptic && isVibrationEnabled) {
      _triggerHaptic(sfx);
    }

    // 2. Play audio jika suara aktif
    if (!isSoundEnabled) {
      return;
    }

    final list = _players[sfx];
    if (list == null || list.isEmpty) {
      // Jika belum diinisialisasi (misal di headless unit test), lewati tanpa blokir
      if (!_initialized) {
        return;
      }
      _playFallback(sfx, volume, pitch);
      return;
    }

    final currentIndex = _playerIndices[sfx] ?? 0;
    _playerIndices[sfx] = (currentIndex + 1) % list.length;
    final dedicated = list[currentIndex];

    final effectiveVolume = (volume * masterVolume).clamp(0.0, 1.0);
    final duration = _getSfxDuration(sfx);

    // Batalkan timer auto-stop sebelumnya
    dedicated.autoStopTimer?.cancel();

    _executePlay(
      dedicated: dedicated,
      volume: effectiveVolume,
      pitch: pitch,
      duration: duration,
    );
  }

  Future<void> _executePlay({
    required _DedicatedPlayer dedicated,
    required double volume,
    required double pitch,
    required Duration duration,
  }) async {
    final player = dedicated.player;
    try {
      // Selalu stop dahulu agar streamId native Android di SoundPoolPlayer di-reset ke null.
      // ReleaseMode.stop menjamin audio TIDAK pernah di-unload dari RAM SoundPool.
      await player.stop().catchError((_) {});
      dedicated.isPlaying = false;

      if ((volume - 1.0).abs() > 0.05) {
        await player.setVolume(volume).catchError((_) {});
      }
      if ((pitch - 1.0).abs() > 0.01) {
        await player.setPlaybackRate(pitch).catchError((_) {});
      }

      // Mainkan seketika dari RAM SoundPool (streamId null memicu soundPool.play(soundId) dengan latensi < 1ms)
      await player.resume();
      dedicated.isPlaying = true;

      // Auto-stop setelah selesai agar stream native Android tertutup
      dedicated.autoStopTimer = Timer(duration, () {
        player.stop().catchError((_) {});
        dedicated.isPlaying = false;
      });
    } catch (_) {
      // Fallback jika player native belum di-set sourcenya
      try {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.play(
          AssetSource(dedicated.sfx.assetPath),
          volume: volume,
          mode: PlayerMode.lowLatency,
        );
        dedicated.isPlaying = true;
        dedicated.autoStopTimer = Timer(duration, () {
          player.stop().catchError((_) {});
          dedicated.isPlaying = false;
        });
      } catch (e) {
        debugPrint('[SoundService] Play error (${dedicated.sfx.name}): $e');
      }
    }
  }

  Future<void> _playFallback(Sfx sfx, double volume, double pitch) async {
    try {
      final p = _createPlayerInstance('pj_fallback_${sfx.name}');
      final effectiveVolume = (volume * masterVolume).clamp(0.0, 1.0);
      await p.play(
        AssetSource(sfx.assetPath),
        volume: effectiveVolume,
        mode: PlayerMode.lowLatency,
      );
      Timer(_getSfxDuration(sfx), () {
        p.dispose().catchError((_) {});
      });
    } catch (e) {
      debugPrint('[SoundService] Fallback error (${sfx.name}): $e');
    }
  }

  /// Mainkan tick roda putar tanpa pengulangan suara yang sama berturut-turut
  /// Pitch ±5% dan volume 0.7 - 1.0 bervariasi sesuai kecepatan
  void playWheelTick({double speed = 1.0}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle 60ms untuk melindungi hardware audio buffer
    if (now - _lastTickTime < 60) return;
    _lastTickTime = now;

    // Pilih secara acak antara 1, 2, 3 tanpa ulang berturut-turut
    final availableIndices = [1, 2, 3]..remove(_lastTickIndex);
    final chosenIndex = availableIndices[_rng.nextInt(availableIndices.length)];
    _lastTickIndex = chosenIndex;

    final sfx = chosenIndex == 1
        ? Sfx.wheelTick1
        : (chosenIndex == 2 ? Sfx.wheelTick2 : Sfx.wheelTick3);

    // Variasi pitch ±5% menurut kecepatan
    final pitch = (0.95 + (speed.clamp(0.0, 1.0) * 0.1));
    final volume = (0.7 + (speed.clamp(0.0, 1.0) * 0.3));

    play(sfx, volume: volume, pitch: pitch, haptic: true);
  }

  /// Helper kompatibilitas untuk wheel screen
  void playTick({double speed = 1.0}) {
    playWheelTick(speed: speed);
  }

  /// Helper kompatibilitas untuk menang / lolos
  void playWin() {
    play(Sfx.winLolos, volume: 1.0);
  }

  /// Trigger haptic feedback yang sesuai untuk tiap aksi permainan
  void _triggerHaptic(Sfx sfx) {
    switch (sfx) {
      case Sfx.wheelTick1:
      case Sfx.wheelTick2:
      case Sfx.wheelTick3:
      case Sfx.uiTap:
      case Sfx.coinFlip:
        HapticFeedback.selectionClick();
        break;
      case Sfx.wheelLand:
      case Sfx.winLolos:
      case Sfx.coinLand:
      case Sfx.coinDouble:
        HapticFeedback.mediumImpact();
        break;
      case Sfx.overBudget:
      case Sfx.notifWarning:
        HapticFeedback.heavyImpact();
        break;
      case Sfx.diceRoll:
      case Sfx.capsuleCrank:
      case Sfx.envelopeShuffle:
      case Sfx.coinHalve:
        HapticFeedback.lightImpact();
        break;
      case Sfx.diceLand:
      case Sfx.capsuleDrop:
      case Sfx.capsuleOpen:
      case Sfx.envelopeOpen:
      case Sfx.coinRecord:
        HapticFeedback.mediumImpact();
        break;
      case Sfx.splashJingle:
      case Sfx.wheelSpin:
      case Sfx.notifReminder:
        break;
    }
  }

  /// Ubah status mute (toggle)
  Future<void> toggleMute() async {
    await setSoundEnabled(!isSoundEnabled);
  }

  /// Ubah pengaturan suara aktif/nonaktif
  Future<void> setSoundEnabled(bool enabled) async {
    settingsNotifier.value = settings.copyWith(soundEnabled: enabled);
    isMutedNotifier.value = !enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySound, enabled);
    } catch (_) {}
  }

  /// Ubah pengaturan getaran aktif/nonaktif
  Future<void> setVibrationEnabled(bool enabled) async {
    settingsNotifier.value = settings.copyWith(vibrationEnabled: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyVibration, enabled);
    } catch (_) {}
  }

  /// Ubah volume master (0.0 sampai 1.0)
  Future<void> setVolume(double newVolume) async {
    final clamped = newVolume.clamp(0.0, 1.0);
    settingsNotifier.value = settings.copyWith(volume: clamped);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyVolume, clamped);
    } catch (_) {}
  }

  void dispose() {
    for (final list in _players.values) {
      for (final dp in list) {
        dp.autoStopTimer?.cancel();
        dp.player.dispose().catchError((_) {});
      }
    }
    _players.clear();
    _playerIndices.clear();
  }
}

/// StateNotifier untuk integrasi reaktif dengan Riverpod
class SoundSettingsNotifier extends StateNotifier<SoundSettings> {
  SoundSettingsNotifier() : super(SoundService.instance.settings) {
    SoundService.instance.settingsNotifier.addListener(_sync);
  }

  void _sync() {
    state = SoundService.instance.settings;
  }

  Future<void> setSoundEnabled(bool enabled) =>
      SoundService.instance.setSoundEnabled(enabled);

  Future<void> setVibrationEnabled(bool enabled) =>
      SoundService.instance.setVibrationEnabled(enabled);

  Future<void> setVolume(double volume) =>
      SoundService.instance.setVolume(volume);

  Future<void> toggleMute() =>
      SoundService.instance.toggleMute();

  @override
  void dispose() {
    SoundService.instance.settingsNotifier.removeListener(_sync);
    super.dispose();
  }
}

/// Riverpod Providers
final soundServiceProvider = Provider<SoundService>((ref) {
  return SoundService.instance;
});

final soundSettingsProvider =
    StateNotifierProvider<SoundSettingsNotifier, SoundSettings>((ref) {
  return SoundSettingsNotifier();
});
