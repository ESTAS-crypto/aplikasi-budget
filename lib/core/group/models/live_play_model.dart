import 'package:flutter/animation.dart';

/// Model siaran permainan langsung (Live Play) untuk sinkronisasi realtime multi-perangkat.
/// Dirancang generik (game: "wheel", "dice", "capsule", "envelope", "coin").
class LivePlayModel {
  final String spinId;
  final String game;
  final int startAtMs;
  final int durationMs;
  final int laps;
  final int resultIndex;
  final double finalAngle;
  final int amount;
  final String startedByUid;
  final String startedByName;
  final int seed;
  final Map<String, dynamic> params;

  const LivePlayModel({
    required this.spinId,
    this.game = 'wheel',
    required this.startAtMs,
    this.durationMs = 6000,
    this.laps = 5,
    required this.resultIndex,
    required this.finalAngle,
    required this.amount,
    required this.startedByUid,
    required this.startedByName,
    this.seed = 0,
    this.params = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'spinId': spinId,
      'game': game,
      'startAtMs': startAtMs,
      'durationMs': durationMs,
      'laps': laps,
      'resultIndex': resultIndex,
      'finalAngle': finalAngle,
      'amount': amount,
      'startedByUid': startedByUid,
      'startedByName': startedByName,
      'seed': seed,
      'params': params,
    };
  }

  factory LivePlayModel.fromMap(Map<String, dynamic> map) {
    return LivePlayModel(
      spinId: map['spinId']?.toString() ?? '',
      game: map['game']?.toString() ?? 'wheel',
      startAtMs: (map['startAtMs'] as num?)?.toInt() ?? 0,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 6000,
      laps: (map['laps'] as num?)?.toInt() ?? 5,
      resultIndex: (map['resultIndex'] as num?)?.toInt() ?? 0,
      finalAngle: (map['finalAngle'] as num?)?.toDouble() ?? 0.0,
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      startedByUid: map['startedByUid']?.toString() ?? '',
      startedByName: map['startedByName']?.toString() ?? '',
      seed: (map['seed'] as num?)?.toInt() ?? 0,
      params: (map['params'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Menghitung progress putaran [0.0..1.0] berdasarkan waktu server sekarang
  double getProgress(int serverNowMs) {
    if (serverNowMs < startAtMs) return 0.0;
    if (durationMs <= 0) return 1.0;
    return ((serverNowMs - startAtMs) / durationMs).clamp(0.0, 1.0);
  }

  /// Menghitung sudut saat ini berdasarkan progress dan kurva cubic-bezier (0.12, 0.7, 0.1, 1.0)
  double getAngleAtProgress(double progress) {
    const curve = Cubic(0.12, 0.7, 0.1, 1.0);
    final curvedProgress = curve.transform(progress.clamp(0.0, 1.0));
    return finalAngle * curvedProgress;
  }

  /// Menghitung sudut tepat pada waktu server tertentu
  double getAngleAtServerTime(int serverNowMs) {
    final progress = getProgress(serverNowMs);
    return getAngleAtProgress(progress);
  }

  /// Cek apakah siaran ini sudah kadaluarsa (lebih tua dari durationMs + 10 detik)
  bool isExpired(int serverNowMs) {
    return serverNowMs > (startAtMs + durationMs + 10000);
  }

  /// Cek apakah putaran sudah selesai
  bool isCompleted(int serverNowMs) {
    return serverNowMs >= (startAtMs + durationMs);
  }
}

