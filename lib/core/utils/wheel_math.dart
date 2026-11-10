import 'dart:math' as math;

class WheelMath {
  WheelMath._();

  /// Menghitung rotasi akhir dalam derajat untuk mendarat pada `targetIndex`
  /// Rumus: segAngle = 360 / n;
  /// rotasi akhir = (putaranPenuh * 360) - (indeks * segAngle + segAngle / 2) + jitter acak ±(segAngle * 0.3)
  static double calculateTargetRotation({
    required int targetIndex,
    required int totalSlots,
    math.Random? random,
    int? fullTurns,
  }) {
    assert(totalSlots >= 2 && totalSlots <= 12, 'Slot harus antara 2 dan 12');
    assert(targetIndex >= 0 && targetIndex < totalSlots, 'Target index tidak valid');

    final rnd = random ?? math.Random.secure();
    final segAngle = 360.0 / totalSlots;
    final turns = fullTurns ?? (5 + rnd.nextInt(3)); // 5 sampai 7 putaran penuh

    // Jitter acak ±(segAngle * 0.3)
    final jitterRange = segAngle * 0.3;
    final jitter = (rnd.nextDouble() * 2 - 1) * jitterRange;

    final targetAngle = (turns * 360.0) -
        (targetIndex * segAngle + segAngle / 2.0) +
        jitter;

    return targetAngle;
  }

  /// Menghitung indeks irisan di bawah pointer (posisi 12 jam) berdasarkan rotasi saat ini
  static int getSliceIndexAtRotation({
    required double rotationDegrees,
    required int totalSlots,
  }) {
    assert(totalSlots > 0);
    final segAngle = 360.0 / totalSlots;
    // Sudut pada roda di bawah pointer 12 jam (arah atas)
    double wheelAngle = (-rotationDegrees) % 360.0;
    if (wheelAngle < 0) wheelAngle += 360.0;

    final index = (wheelAngle / segAngle).floor() % totalSlots;
    return index;
  }

  /// Menghitung apakah ada batas irisan yang terlewati antara sudut sebelumnya dan sekarang
  static bool hasCrossedSliceBoundary({
    required double previousAngle,
    required double currentAngle,
    required int totalSlots,
  }) {
    if (totalSlots <= 0) return false;
    final segAngle = 360.0 / totalSlots;
    final prevCount = (previousAngle / segAngle).floor();
    final currCount = (currentAngle / segAngle).floor();
    return prevCount != currCount;
  }

  /// Menghitung sudut lentur jarum pointer (posisi jam 12) secara geometris murni
  /// berdasarkan posisi pasak/garis pembatas irisan saat ini.
  /// - Menghilangkan 100% delay atau jarum macet di garis pembatas.
  /// - Memberikan fisika responsif mekanikal di 60fps/120fps tanpa ketergantungan controller statis.
  static double calculatePointerFlickAngle({
    required double currentAngle,
    required int totalSlots,
    double pushZone = 7.0,
    double snapZone = 3.5,
    double maxDeflection = 13.0,
  }) {
    if (totalSlots <= 0) return 0.0;
    final segAngle = 360.0 / totalSlots;
    final offset = (currentAngle % segAngle + segAngle) % segAngle;
    final distToPeg = segAngle - offset;

    if (distToPeg <= pushZone) {
      // Garis pembatas sedang menabrak dan mendorong jarum pointer ke arah putaran
      final t = (pushZone - distToPeg) / pushZone;
      return maxDeflection * t;
    } else if (offset <= snapZone) {
      // Jarum baru saja lepas dari garis dan membal elastis ke arah berlawanan
      final t = (snapZone - offset) / snapZone;
      return -5.0 * t;
    }
    return 0.0;
  }
}
