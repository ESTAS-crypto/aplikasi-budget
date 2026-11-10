import 'dart:math';

/// Tipe permainan yang tersedia di Putar Jajan
enum GameType {
  wheel,
  dice,
  capsule,
  envelope,
  coin;

  String get label {
    switch (this) {
      case GameType.wheel:
        return 'Roda Putar';
      case GameType.dice:
        return 'Kocok Dadu';
      case GameType.capsule:
        return 'Gacha Kapsul';
      case GameType.envelope:
        return 'Pilih Amplop';
      case GameType.coin:
        return 'Lempar Koin';
    }
  }

  String get subtitle {
    switch (this) {
      case GameType.wheel:
        return 'Klasik. Putar roda, terima nasib.';
      case GameType.dice:
        return 'Dua dadu, hasilnya dikali nominal.';
      case GameType.capsule:
        return 'Putar tuas, kapsul jatuh.';
      case GameType.envelope:
        return 'Tiga amplop, satu pilihan.';
      case GameType.coin:
        return 'Gandakan atau setengah.';
    }
  }
}

/// Hasil permainan yang telah ditentukan secara deterministik sebelum animasi
class GameOutcome {
  final int amount;
  final GameType gameType;
  final Map<String, dynamic> animationParameters;

  const GameOutcome({
    required this.amount,
    required this.gameType,
    required this.animationParameters,
  });

  int get wonAmount => amount;
}

/// Abstraksi engine permainan deterministik dengan Random.secure
abstract class GameEngine {
  GameType get gameType;
  GameOutcome play([Random? rng]);
}

/// Engine untuk Roda Putar
class WheelGameEngine implements GameEngine {
  final List<int> slots;

  static const List<int> defaultSlots = [
    20000,
    40000,
    60000,
    100000,
    30000,
    150000,
    50000,
    80000,
  ];

  WheelGameEngine({List<int>? slots}) : slots = slots ?? defaultSlots;

  @override
  GameType get gameType => GameType.wheel;

  @override
  GameOutcome play([Random? rng]) {
    final secureRng = rng ?? Random.secure();
    final n = slots.length;
    final targetIndex = secureRng.nextInt(n);
    final amount = slots[targetIndex];

    // Rumus dari AGENT_PROMPT.md & UPDATE_1_PERMAINAN_DAN_SUARA.md:
    // segAngle = 360 / n
    // putaranPenuh: 5 sampai 7
    // jitter acak: ±(segAngle * 0.3)
    // rotasi akhir = putaranPenuh * 360 - (indeks * segAngle + segAngle / 2) + jitter
    final segAngle = 360.0 / n;
    final fullTurns = 5 + secureRng.nextInt(3); // 5, 6, atau 7
    final jitterFraction = (secureRng.nextDouble() * 0.6) - 0.3; // -0.3 sampai +0.3
    final jitter = jitterFraction * segAngle;

    final targetAngle = (fullTurns * 360.0) - (targetIndex * segAngle + (segAngle / 2.0)) + jitter;

    return GameOutcome(
      amount: amount,
      gameType: GameType.wheel,
      animationParameters: {
        'targetIndex': targetIndex,
        'finalRotation': targetAngle,
        'fullTurns': fullTurns,
        'jitter': jitter,
        'segAngle': segAngle,
      },
    );
  }
}

/// Alias kompatibilitas WheelEngine sesuai spesifikasi UPDATE 1
typedef WheelEngine = WheelGameEngine;

/// Engine untuk Kocok Dadu
class DiceGameEngine implements GameEngine {
  final int diceCount;
  final int multiplier;

  DiceGameEngine({
    this.diceCount = 2,
    this.multiplier = 10000,
  });

  @override
  GameType get gameType => GameType.dice;

  @override
  GameOutcome play([Random? rng]) {
    final secureRng = rng ?? Random.secure();
    final diceValues = <int>[];
    int sum = 0;

    for (int i = 0; i < diceCount; i++) {
      final value = 1 + secureRng.nextInt(6);
      diceValues.add(value);
      sum += value;
    }

    final totalAmount = sum * multiplier;

    return GameOutcome(
      amount: totalAmount,
      gameType: GameType.dice,
      animationParameters: {
        'diceCount': diceCount,
        'multiplier': multiplier,
        'diceValues': diceValues,
        'rolls': diceValues, // Alias kompatibel untuk UI
        'diceSum': sum,
      },
    );
  }
}

/// Engine untuk Gacha Kapsul
class CapsuleGameEngine implements GameEngine {
  final List<int> pool;

  static const List<int> defaultPool = [
    25000,
    35000,
    50000,
    75000,
    100000,
    125000,
  ];

  static const List<String> capsuleColors = [
    '#FF6B5A', // Tomat
    '#3DDBB0', // Mint
    '#FFD23F', // Matahari
    '#6FB1FF', // Langit
    '#FF8FC0', // Permen
    '#B58DFF', // Lavender
  ];

  CapsuleGameEngine({List<int>? pool}) : pool = pool ?? defaultPool;

  @override
  GameType get gameType => GameType.capsule;

  @override
  GameOutcome play([Random? rng]) {
    final secureRng = rng ?? Random.secure();
    final targetIndex = secureRng.nextInt(pool.length);
    final amount = pool[targetIndex];
    final capsuleColor = capsuleColors[targetIndex % capsuleColors.length];

    return GameOutcome(
      amount: amount,
      gameType: GameType.capsule,
      animationParameters: {
        'targetIndex': targetIndex,
        'totalCapsules': pool.length,
        'capsuleColor': capsuleColor,
      },
    );
  }
}

/// Engine untuk Pilih Amplop
class EnvelopeGameEngine implements GameEngine {
  final List<int> pool;

  static const List<int> defaultPool = [
    30000,
    50000,
    80000,
    100000,
    150000,
  ];

  EnvelopeGameEngine({List<int>? pool}) : pool = pool ?? defaultPool;

  @override
  GameType get gameType => GameType.envelope;

  @override
  GameOutcome play([Random? rng]) {
    final secureRng = rng ?? Random.secure();
    // Ambil 3 nominal acak dari pool
    final available = List<int>.from(pool)..shuffle(secureRng);
    final chosen3 = available.take(3).toList();
    final targetIndex = secureRng.nextInt(3);

    return GameOutcome(
      amount: chosen3[targetIndex],
      gameType: GameType.envelope,
      animationParameters: {
        'envelopeAmounts': chosen3,
        'candidatePool': chosen3, // Alias kompatibel untuk UI
        'targetIndex': targetIndex,
      },
    );
  }
}

/// Sisi Koin: Gambar (x2) atau Angka (½)
enum CoinSide {
  gambar,
  angka;

  String get label => this == CoinSide.gambar ? 'Gambar' : 'Angka';
}

/// Rekaman satu lemparan koin
class CoinFlipStep {
  final int flipIndex; // 1, 2, 3
  final CoinSide side;
  final int beforeAmount;
  final int afterAmount;

  const CoinFlipStep({
    required this.flipIndex,
    required this.side,
    required this.beforeAmount,
    required this.afterAmount,
  });

  Map<String, dynamic> toJson() => {
    'flipIndex': flipIndex,
    'side': side.name,
    'beforeAmount': beforeAmount,
    'afterAmount': afterAmount,
  };

  factory CoinFlipStep.fromJson(Map<String, dynamic> json) {
    return CoinFlipStep(
      flipIndex: json['flipIndex'] as int,
      side: (json['side'] as String) == 'gambar' ? CoinSide.gambar : CoinSide.angka,
      beforeAmount: json['beforeAmount'] as int,
      afterAmount: json['afterAmount'] as int,
    );
  }
}

/// Engine untuk Lempar Koin (Layar 15)
/// Gambar = x2, Angka = setengah (dibulatkan ke bawah kelipatan Rp1.000, minimum Rp1.000)
/// Dilempar 1 sampai 3 kali berturut-turut. Semua hasil lemparan ditentukan DULU secara deterministik.
class CoinGameEngine implements GameEngine {
  final int baseAmount;

  static const int defaultBaseAmount = 50000;
  static const List<int> presetBaseAmounts = [30000, 50000, 100000];

  CoinGameEngine({int? baseAmount})
      : baseAmount = baseAmount ?? defaultBaseAmount;

  @override
  GameType get gameType => GameType.coin;

  /// Hitung setengah: dibulatkan ke bawah kelipatan Rp1.000, minimum Rp1.000
  static int calculateHalf(int current) {
    final half = current ~/ 2;
    final rounded = (half ~/ 1000) * 1000;
    return max(1000, rounded);
  }

  /// Hitung dua kali lipat
  static int calculateDouble(int current) {
    return current * 2;
  }

  @override
  GameOutcome play([Random? rng]) {
    final secureRng = rng ?? Random.secure();
    final steps = <CoinFlipStep>[];
    int current = baseAmount;

    // Tentukan DULU ketiga kemungkinan lemparan koin secara deterministik
    for (int i = 1; i <= 3; i++) {
      final isGambar = secureRng.nextBool(); // 50/50 probabilitas
      final side = isGambar ? CoinSide.gambar : CoinSide.angka;
      final before = current;
      final after = isGambar ? calculateDouble(before) : calculateHalf(before);
      steps.add(CoinFlipStep(
        flipIndex: i,
        side: side,
        beforeAmount: before,
        afterAmount: after,
      ));
      current = after;
    }

    return GameOutcome(
      amount: current,
      gameType: GameType.coin,
      animationParameters: {
        'baseAmount': baseAmount,
        'steps': steps.map((s) => s.toJson()).toList(),
        'sides': steps.map((s) => s.side.name).toList(),
        'amounts': steps.map((s) => s.afterAmount).toList(),
      },
    );
  }
}
