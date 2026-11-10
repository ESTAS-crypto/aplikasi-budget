import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/group/models/live_play_model.dart';
import 'package:putar_jajan/core/group/services/clock_sync_service.dart';
import 'package:putar_jajan/core/group/widgets/live_spin_overlay.dart';
import 'package:putar_jajan/core/utils/wheel_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String ownerUid = 'uid_host_raka';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('F2 Mandatory Tests: Roda Berputar Realtime di Semua HP', () {
    test('1. ClockSyncService menghitung offset dan serverNowMs dengan benar', () {
      final sync = ClockSyncService();
      expect(sync.offsetMs, equals(0));

      // Simulasikan selisih waktu server +5000ms
      sync.setOffsetForTesting(5000);
      expect(sync.offsetMs, equals(5000));

      final localNow = DateTime.now().millisecondsSinceEpoch;
      final serverNow = sync.serverNowMs;
      expect((serverNow - localNow - 5000).abs(), lessThan(50));
    });

    test('2. LivePlayModel serialisasi toMap dan fromMap identik', () {
      final play = LivePlayModel(
        spinId: 'spin_12345',
        game: 'wheel',
        startAtMs: 1700000000000,
        durationMs: 6000,
        laps: 6,
        resultIndex: 3,
        finalAngle: 2362.5,
        amount: 80000,
        startedByUid: ownerUid,
        startedByName: 'Raka',
        seed: 42,
        params: {'slots': [20000, 30000, 50000, 80000, 100000, 120000, 150000, 200000]},
      );

      final map = play.toMap();
      final reconstructed = LivePlayModel.fromMap(map);

      expect(reconstructed.spinId, equals(play.spinId));
      expect(reconstructed.game, equals('wheel'));
      expect(reconstructed.startAtMs, equals(play.startAtMs));
      expect(reconstructed.durationMs, equals(6000));
      expect(reconstructed.laps, equals(6));
      expect(reconstructed.resultIndex, equals(3));
      expect(reconstructed.finalAngle, equals(2362.5));
      expect(reconstructed.amount, equals(80000));
      expect(reconstructed.startedByUid, equals(ownerUid));
      expect(reconstructed.startedByName, equals('Raka'));
      expect(reconstructed.seed, equals(42));
      expect(reconstructed.params['slots'], equals(play.params['slots']));
    });

    test('3. Sudut sebagai fungsi waktu: dua HP sinkron dengan selisih waktu < 300ms berhenti pada hasil yang sama', () {
      const startAtMs = 100000;
      const durationMs = 6000;
      const finalAngle = 2362.5; // Menghasilkan winning slot index 3

      final play = LivePlayModel(
        spinId: 'spin_sync_test',
        startAtMs: startAtMs,
        durationMs: durationMs,
        laps: 6,
        resultIndex: 3,
        finalAngle: finalAngle,
        amount: 80000,
        startedByUid: ownerUid,
        startedByName: 'Raka',
      );

      // HP Host pada t = 103000 (3 detik setelah mulai, progress 50%)
      final hostAngle = play.getAngleAtServerTime(startAtMs + 3000);

      // HP Anggota dengan jeda transit jaringan 150ms (t = 103150)
      final memberAngle = play.getAngleAtServerTime(startAtMs + 3150);

      // Selisih sudut antara kedua HP kecil karena fungsi kurva waktu kontinu
      expect((hostAngle - memberAngle).abs(), lessThan(150.0));

      // Saat keduanya mencapai t >= startAtMs + durationMs, keduanya berhenti persis pada finalAngle
      final hostFinal = play.getAngleAtServerTime(startAtMs + 6000);
      final memberFinal = play.getAngleAtServerTime(startAtMs + 6100);

      expect(hostFinal, equals(finalAngle));
      expect(memberFinal, equals(finalAngle));

      // Verifikasi kedua HP mendarat pada slot index yang sama persis
      final hostSlice = WheelMath.getSliceIndexAtRotation(
        rotationDegrees: hostFinal,
        totalSlots: 8,
      );
      final memberSlice = WheelMath.getSliceIndexAtRotation(
        rotationDegrees: memberFinal,
        totalSlots: 8,
      );
      expect(hostSlice, equals(3));
      expect(memberSlice, equals(3));
    });

    test('4. Anggota yang masuk di tengah putaran (late joiner) langsung melihat posisi sudut yang benar', () {
      const startAtMs = 50000;
      const durationMs = 6000;
      const finalAngle = 2160.0;

      final play = LivePlayModel(
        spinId: 'spin_late_joiner',
        startAtMs: startAtMs,
        durationMs: durationMs,
        laps: 6,
        resultIndex: 0,
        finalAngle: finalAngle,
        amount: 50000,
        startedByUid: ownerUid,
        startedByName: 'Raka',
      );

      // Anggota masuk 4 detik setelah putaran dimulai (progress = 4000/6000 = 0.6667)
      final progressAtJoin = play.getProgress(startAtMs + 4000);
      expect(progressAtJoin, closeTo(4000 / 6000, 0.001));

      // Sudut tidak mulai dari 0, melainkan langsung pada posisi kurva saat itu
      final angleAtJoin = play.getAngleAtProgress(progressAtJoin);
      const curve = Cubic(0.12, 0.7, 0.1, 1.0);
      final expectedAngle = finalAngle * curve.transform(progressAtJoin);

      expect(angleAtJoin, equals(expectedAngle));
      expect(angleAtJoin, greaterThan(1500.0));
      expect(play.isCompleted(startAtMs + 4000), isFalse);
    });

    test('5. Tidak ada putaran ulang setelah restart aplikasi (siaran > 16 detik kedaluwarsa)', () {
      const startAtMs = 100000;
      const durationMs = 6000;

      final play = LivePlayModel(
        spinId: 'spin_expired_test',
        startAtMs: startAtMs,
        durationMs: durationMs,
        laps: 5,
        resultIndex: 1,
        finalAngle: 1800.0,
        amount: 25000,
        startedByUid: ownerUid,
        startedByName: 'Raka',
      );

      // Saat putaran selesai (t = 106000): selesai, tapi belum kedaluwarsa (< 16 detik)
      expect(play.isCompleted(106000), isTrue);
      expect(play.isExpired(106000), isFalse);

      // 5 detik setelah selesai (t = 111000): belum kedaluwarsa
      expect(play.isExpired(111000), isFalse);

      // 17 detik setelah mulai (t = 117000 > startAtMs + durationMs + 10s): KEDALUWARSA!
      // Aplikasi yang dibuka kembali setelah waktu ini TIDAK AKAN memutar ulang roda!
      expect(play.isExpired(117000), isTrue);
    });

    testWidgets('6. LiveSpinOverlay merender nama pemutar, roda, dan kartu hasil saat selesai', (tester) async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      // Putaran yang sudah selesai beberapa saat lalu (completed tapi belum expired)
      final completedPlay = LivePlayModel(
        spinId: 'spin_completed_widget_test',
        startAtMs: nowMs - 7000, // Dimulai 7 detik lalu (selesai 1 detik lalu)
        durationMs: 6000,
        laps: 6,
        resultIndex: 2,
        finalAngle: 2200.0,
        amount: 75000,
        startedByUid: ownerUid,
        startedByName: 'Raka',
        params: {
          'slots': [20000, 30000, 50000, 75000, 100000, 150000],
        },
      );

      bool dismissed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LiveSpinOverlay(
                play: completedPlay,
                onDismiss: () {
                  dismissed = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Memeriksa tampilan judul dan teks pemutar
      expect(find.text('Raka memutar roda!'), findsOneWidget);
      expect(find.text('SIARAN LANGSUNG'), findsOneWidget);
      expect(find.text('BUDGET DITENTUKAN'), findsOneWidget);
      expect(find.text('Rp75.000'), findsOneWidget);

      // Hitung mundur 3 detik auto-dismiss
      await tester.pump(const Duration(seconds: 4));
      expect(dismissed, isTrue);
    });
  });
}

