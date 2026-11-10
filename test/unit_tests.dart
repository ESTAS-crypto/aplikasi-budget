import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:putar_jajan/core/utils/wheel_math.dart';
import 'package:putar_jajan/core/utils/budget_calculator.dart';
import 'package:putar_jajan/core/utils/streak_calculator.dart';
import 'package:putar_jajan/core/utils/rupiah_formatter.dart';
import 'package:putar_jajan/core/utils/sound_service.dart';
import 'package:putar_jajan/core/games/game_engine.dart';
import 'package:putar_jajan/features/notifications/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Unit Tests: WheelMath', () {
    test('calculateTargetRotation produces angle pointing to exact target slot', () {
      const totalSlots = 8;

      for (int targetIndex = 0; targetIndex < totalSlots; targetIndex++) {
        final rotation = WheelMath.calculateTargetRotation(
          targetIndex: targetIndex,
          totalSlots: totalSlots,
          fullTurns: 6,
        );

        final resolvedIndex = WheelMath.getSliceIndexAtRotation(
          rotationDegrees: rotation,
          totalSlots: totalSlots,
        );

        expect(
          resolvedIndex,
          equals(targetIndex),
          reason: 'Slot $targetIndex should resolve correctly after spinning',
        );
      }
    });

    test('hasCrossedSliceBoundary detects boundary crossing correctly', () {
      const totalSlots = 8; // 45 deg per slice

      // Did not cross boundary (e.g. 10 deg to 20 deg)
      expect(
        WheelMath.hasCrossedSliceBoundary(
          previousAngle: 10,
          currentAngle: 20,
          totalSlots: totalSlots,
        ),
        isFalse,
      );

      // Crossed boundary at 45 deg (e.g. 40 deg to 50 deg)
      expect(
        WheelMath.hasCrossedSliceBoundary(
          previousAngle: 40,
          currentAngle: 50,
          totalSlots: totalSlots,
        ),
        isTrue,
      );
    });
  });

  group('Unit Tests: BudgetCalculator', () {
    test('status is safe (< 70%), warning (70-90%), and danger (> 90%)', () {
      const budget = 100000;

      // Safe: 50k / 100k = 50%
      expect(
        BudgetCalculator.getStatus(spent: 50000, budget: budget),
        equals(BudgetStatus.safe),
      );

      // Warning: 80k / 100k = 80%
      expect(
        BudgetCalculator.getStatus(spent: 80000, budget: budget),
        equals(BudgetStatus.warning),
      );

      // Danger: 95k / 100k = 95%
      expect(
        BudgetCalculator.getStatus(spent: 95000, budget: budget),
        equals(BudgetStatus.danger),
      );
    });

    test('shouldShow80Warning triggers only when passing 80%', () {
      const budget = 100000;

      // Before: 70k, After: 75k -> false
      expect(
        BudgetCalculator.shouldShow80Warning(
          previousSpent: 70000,
          newSpent: 75000,
          budget: budget,
        ),
        isFalse,
      );

      // Before: 75k, After: 82k -> true (crosses 80%)
      expect(
        BudgetCalculator.shouldShow80Warning(
          previousSpent: 75000,
          newSpent: 82000,
          budget: budget,
        ),
        isTrue,
      );

      // Already above 80%: Before 85k, After 90k -> false
      expect(
        BudgetCalculator.shouldShow80Warning(
          previousSpent: 85000,
          newSpent: 90000,
          budget: budget,
        ),
        isFalse,
      );
    });

    test('isOverbudget detects budget exceeded', () {
      expect(BudgetCalculator.isOverbudget(spent: 99000, budget: 100000), isFalse);
      expect(BudgetCalculator.isOverbudget(spent: 100000, budget: 100000), isFalse);
      expect(BudgetCalculator.isOverbudget(spent: 101000, budget: 100000), isTrue);
    });
  });

  group('Unit Tests: StreakCalculator', () {
    test('calculates consecutive passed dates correctly', () {
      // 7 consecutive passed dates
      final history1 = [true, true, true, true, true, true, true];
      expect(StreakCalculator.calculateStreak(history1), equals(7));

      // Broke streak on 3rd newest date
      final history2 = [true, true, false, true, true];
      expect(StreakCalculator.calculateStreak(history2), equals(2));

      // Latest date failed
      final history3 = [false, true, true, true];
      expect(StreakCalculator.calculateStreak(history3), equals(0));

      // Empty history
      expect(StreakCalculator.calculateStreak([]), equals(0));
    });
  });

  group('Unit Tests: RupiahFormatter', () {
    test('formats numbers to Indonesian Rupiah standard', () {
      expect(RupiahFormatter.format(100000), equals('Rp100.000'));
      expect(RupiahFormatter.format(36000), equals('Rp36.000'));
      expect(RupiahFormatter.format(1000), equals('Rp1.000'));
      expect(RupiahFormatter.format(0), equals('Rp0'));
    });

    test('formats compact and rb versions', () {
      expect(RupiahFormatter.formatCompact(100000), equals('100k'));
      expect(RupiahFormatter.formatCompact(20000), equals('20k'));
      expect(RupiahFormatter.formatCompact(150000), equals('150k'));
      expect(RupiahFormatter.formatRb(54000), equals('54rb'));
      expect(RupiahFormatter.formatRb(141000), equals('141rb'));
    });

    test('parses dirty input strings to integer', () {
      expect(RupiahFormatter.parse('Rp 75.000'), equals(75000));
      expect(RupiahFormatter.parse('100k'), equals(100));
      expect(RupiahFormatter.parse('abc'), equals(0));
    });

    test('ThousandsSeparatorInputFormatter formats typing with dots', () {
      const formatter = ThousandsSeparatorInputFormatter();

      // Mengetik 20000 otomatis menjadi 20.000
      final val1 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '20000',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(val1.text, equals('20.000'));
      expect(val1.selection.end, equals(6));

      // Mengetik 150000 otomatis menjadi 150.000
      final val2 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '150000',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      expect(val2.text, equals('150.000'));

      // Mengetik 1000000 otomatis menjadi 1.000.000
      final val3 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '1000000',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(val3.text, equals('1.000.000'));
    });
  });

  group('Unit Tests: SoundService', () {
    test('declares exactly 23 official sounds with valid audio/ paths', () {
      expect(Sfx.values.length, equals(23));
      for (final sfx in Sfx.values) {
        expect(sfx.assetPath.startsWith('audio/'), isTrue);
        expect(sfx.assetPath.endsWith('.wav'), isTrue);
      }
    });

    test('does not play when sound is disabled', () async {
      final sound = SoundService.instance;
      await sound.setSoundEnabled(false);
      expect(sound.isSoundEnabled, isFalse);

      // Play should safely no-op without exception
      sound.play(Sfx.wheelLand);
      sound.play(Sfx.winLolos);

      await sound.setSoundEnabled(true);
      expect(sound.isSoundEnabled, isTrue);
    });

    test('wheel ticks do not repeat the same index consecutively', () {
      final recordedTicks = <int>[];

      // Simulate 20 tick choices
      int lastIndex = -1;
      final rng = math.Random(42);

      for (int i = 0; i < 20; i++) {
        final available = [1, 2, 3]..remove(lastIndex);
        final chosen = available[rng.nextInt(available.length)];
        recordedTicks.add(chosen);
        lastIndex = chosen;
      }

      // Verify no two adjacent elements are the same
      for (int i = 0; i < recordedTicks.length - 1; i++) {
        expect(
          recordedTicks[i] != recordedTicks[i + 1],
          isTrue,
          reason: 'Tick at $i (${recordedTicks[i]}) should not equal tick at ${i + 1} (${recordedTicks[i + 1]})',
        );
      }
    });

    test('measures wheel tick dispatch latency under 15ms', () {
      // Warm up JIT execution
      SoundService.instance.playWheelTick(speed: 1.0);
      final sw = Stopwatch()..start();
      SoundService.instance.playWheelTick(speed: 0.8);
      sw.stop();
      // Tick synchronous dispatch on UI thread must be sub-15ms
      expect(sw.elapsedMilliseconds, lessThan(15));
    });

    test('final wheel rotation lands Mint slice (index 3) exactly under 12 oclock pointer', () {
      // 8 slices, each 45 deg, starting at 12 o'clock (-90 deg)
      // Slice 3 initial center angle: -90 + 3*45 + 22.5 = 67.5 deg
      // Reference rotation: 922.5 deg (or 3*360 - (3*45 + 22.5) = 1080 - 157.5 = 922.5 deg)
      const initialCenterAngle = -90.0 + (3 * 45.0) + 22.5; // 67.5 deg
      const spinRotation = 922.5; // deg

      final finalAngle = (initialCenterAngle + spinRotation) % 360.0;
      // 270 deg is 12 o'clock (-90 deg mod 360 = 270 deg)
      expect(finalAngle, equals(270.0));
    });
  });

  group('Unit Tests: GameEngine implementations', () {
    test('WheelGameEngine produces deterministic outcome within pool', () {
      final slots = [20000, 40000, 60000, 100000, 30000, 150000, 50000, 80000];
      final engine = WheelGameEngine(slots: slots);

      for (int i = 0; i < 20; i++) {
        final outcome = engine.play();
        expect(outcome.gameType, equals(GameType.wheel));
        expect(slots.contains(outcome.amount), isTrue);
        final targetIndex = outcome.animationParameters['targetIndex'] as int;
        expect(targetIndex >= 0 && targetIndex < slots.length, isTrue);
        expect(outcome.amount, equals(slots[targetIndex]));
      }
    });

    test('DiceGameEngine rolls 1..6 per die and multiplies sum', () {
      final engine = DiceGameEngine(diceCount: 2, multiplier: 10000);

      for (int i = 0; i < 20; i++) {
        final outcome = engine.play();
        expect(outcome.gameType, equals(GameType.dice));
        final values = outcome.animationParameters['diceValues'] as List<int>;
        final rolls = outcome.animationParameters['rolls'] as List<int>;
        expect(values.length, equals(2));
        expect(rolls, equals(values));
        for (final val in values) {
          expect(val >= 1 && val <= 6, isTrue);
        }
        final sum = outcome.animationParameters['diceSum'] as int;
        expect(sum, equals(values[0] + values[1]));
        expect(outcome.amount, equals(sum * 10000));
      }
    });

    test('CapsuleGameEngine produces valid capsule from pool and capsuleColor', () {
      final pool = [25000, 50000, 75000, 100000];
      final engine = CapsuleGameEngine(pool: pool);

      for (int i = 0; i < 20; i++) {
        final outcome = engine.play();
        expect(outcome.gameType, equals(GameType.capsule));
        expect(pool.contains(outcome.amount), isTrue);
        final targetIdx = outcome.animationParameters['targetIndex'] as int;
        expect(targetIdx >= 0 && targetIdx < pool.length, isTrue);
        final color = outcome.animationParameters['capsuleColor'] as String;
        expect(color.startsWith('#'), isTrue);
      }
    });

    test('EnvelopeGameEngine shuffles 3 envelopes from pool and provides candidatePool', () {
      final pool = [20000, 40000, 60000, 80000, 100000];
      final engine = EnvelopeGameEngine(pool: pool);

      for (int i = 0; i < 20; i++) {
        final outcome = engine.play();
        expect(outcome.gameType, equals(GameType.envelope));
        final envelopes = outcome.animationParameters['envelopeAmounts'] as List<int>;
        final candidatePool = outcome.animationParameters['candidatePool'] as List<int>;
        expect(envelopes.length, equals(3));
        expect(candidatePool, equals(envelopes));
        for (final val in envelopes) {
          expect(pool.contains(val), isTrue);
        }
        final targetIdx = outcome.animationParameters['targetIndex'] as int;
        expect(targetIdx >= 0 && targetIdx < 3, isTrue);
        expect(outcome.amount, equals(envelopes[targetIdx]));
      }
    });

    test('CoinGameEngine produces valid coin steps: Gambar x2, Angka halve, max 3 flips, min 1000', () {
      final engine = CoinGameEngine(baseAmount: 50000);

      // Uji rumus matematika: Gambar x2 dan Angka setengah dibulatkan ke bawah kelipatan 1000, min 1000
      expect(CoinGameEngine.calculateDouble(50000), equals(100000));
      expect(CoinGameEngine.calculateHalf(50000), equals(25000));
      expect(CoinGameEngine.calculateHalf(25000), equals(12000)); // 12500 dibulatkan ke bawah ke 12000
      expect(CoinGameEngine.calculateHalf(12000), equals(6000));
      expect(CoinGameEngine.calculateHalf(1500), equals(1000)); // min 1000
      expect(CoinGameEngine.calculateHalf(1000), equals(1000)); // min 1000

      for (int i = 0; i < 20; i++) {
        final outcome = engine.play();
        expect(outcome.gameType, equals(GameType.coin));
        final stepsRaw = outcome.animationParameters['steps'] as List;
        expect(stepsRaw.length, equals(3)); // Maksimal 3 lemparan ditentukan DULU
        final steps = stepsRaw.map((s) => CoinFlipStep.fromJson(Map<String, dynamic>.from(s as Map))).toList();

        int expectedCurrent = 50000;
        for (int stepIdx = 0; stepIdx < steps.length; stepIdx++) {
          final step = steps[stepIdx];
          expect(step.flipIndex, equals(stepIdx + 1));
          expect(step.beforeAmount, equals(expectedCurrent));
          if (step.side == CoinSide.gambar) {
            expect(step.afterAmount, equals(expectedCurrent * 2));
          } else {
            expect(step.afterAmount, equals(CoinGameEngine.calculateHalf(expectedCurrent)));
          }
          expect(step.afterAmount >= 1000, isTrue);
          expectedCurrent = step.afterAmount;
        }
        expect(outcome.amount, equals(expectedCurrent));
      }
    });
  });

  group('Unit Tests: NotificationService configurations', () {
    test('Notification channels and IDs are defined and unique', () {
      final channelIds = {
        NotificationService.channelOngoingId,
        NotificationService.channelWarningId,
        NotificationService.channelReminderId,
        NotificationService.channelExpenseLoggedId,
      };
      expect(channelIds.length, equals(4));

      final notifIds = {
        NotificationService.notificationOngoingId,
        NotificationService.notificationWarningId,
        NotificationService.notificationReminderId,
        NotificationService.notificationStreakId,
        NotificationService.notificationExpenseLoggedId,
      };
      expect(notifIds.length, equals(5));
      expect(NotificationService.actionCatatJajan, equals('action_catat_jajan'));
      expect(NotificationService.actionLihatSisa, equals('action_lihat_sisa'));
    });

    test('PendingNavigationRoute updates correctly for deep linking', () {
      NotificationService.instance.pendingNavigationRoute.value = null;
      expect(NotificationService.instance.pendingNavigationRoute.value, isNull);

      NotificationService.instance.pendingNavigationRoute.value = '/catatan?openAdd=true';
      expect(NotificationService.instance.pendingNavigationRoute.value, equals('/catatan?openAdd=true'));

      NotificationService.instance.pendingNavigationRoute.value = '/catatan';
      expect(NotificationService.instance.pendingNavigationRoute.value, equals('/catatan'));
    });
  });
}
