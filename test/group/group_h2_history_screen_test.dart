import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/widgets/scope_switcher.dart';
import 'package:putar_jajan/core/theme/app_theme.dart';
import 'package:putar_jajan/features/group/screens/group_history_view.dart';
import 'package:putar_jajan/features/history/history_screen.dart';

void main() {
  late SharedPreferences prefs;

  final sampleGroup = GroupModel(
    id: 'grp_jumat',
    name: 'Date Jumat',
    code: 'JMT123',
    ownerUid: 'u_kamu',
    createdAt: DateTime(2026, 10, 1, 18, 0),
  );

  final sampleSessions = <GroupSessionModel>[
    GroupSessionModel(
      sessionId: 'sess_4',
      gid: 'grp_jumat',
      budget: 200000,
      game: 'wheel',
      startedByUid: 'u_raka',
      startedByName: 'Raka',
      startedAt: DateTime(2026, 10, 30, 19, 0),
      endedAt: DateTime(2026, 10, 30, 21, 30),
      endedByUid: 'u_kamu',
      endedByName: 'Kamu',
      budgetByUid: 'u_raka',
      budgetByName: 'Raka',
      status: 'lewat',
      totalSpent: 212000,
    ),
    GroupSessionModel(
      sessionId: 'sess_3',
      gid: 'grp_jumat',
      budget: 80000,
      game: 'dice',
      startedByUid: 'u_dina',
      startedByName: 'Dina',
      startedAt: DateTime(2026, 10, 23, 19, 10),
      endedAt: DateTime(2026, 10, 23, 21, 45),
      endedByUid: 'u_kamu',
      endedByName: 'Kamu',
      budgetByUid: 'u_dina',
      budgetByName: 'Dina',
      status: 'lolos',
      totalSpent: 54000,
    ),
    GroupSessionModel(
      sessionId: 'sess_2',
      gid: 'grp_jumat',
      budget: 150000,
      game: 'capsule',
      startedByUid: 'u_kamu',
      startedByName: 'Kamu',
      startedAt: DateTime(2026, 10, 16, 19, 0),
      endedAt: DateTime(2026, 10, 16, 21, 0),
      endedByUid: 'u_kamu',
      endedByName: 'Kamu',
      budgetByUid: 'u_kamu',
      budgetByName: 'Kamu',
      status: 'lolos',
      totalSpent: 141000,
    ),
    GroupSessionModel(
      sessionId: 'sess_1',
      gid: 'grp_jumat',
      budget: 40000,
      game: 'envelope',
      startedByUid: 'u_bima',
      startedByName: 'Bima',
      startedAt: DateTime(2026, 10, 9, 19, 0),
      endedAt: DateTime(2026, 10, 9, 21, 0),
      endedByUid: 'u_kamu',
      endedByName: 'Kamu',
      budgetByUid: 'u_bima',
      budgetByName: 'Bima',
      status: 'lewat',
      totalSpent: 52000,
    ),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      GroupService.keyActiveGroupId: 'grp_jumat',
      'pj_local_uid': 'u_kamu',
      'pj_display_name': 'Kamu',
    });
    prefs = await SharedPreferences.getInstance();
    setGlobalSharedPreferences(prefs);
  });

  Widget buildTestApp({
    required List<GroupSessionModel> sessions,
    double textScale = 1.0,
  }) {
    final router = GoRouter(
      initialLocation: '/riwayat',
      routes: [
        GoRoute(
          path: '/riwayat',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/group/history/:gid/:sessionId',
          builder: (context, state) {
            final sid = state.pathParameters['sessionId'] ?? '';
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('DETAIL_SESI:$sid'),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('KEMBALI'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appScopeProvider.overrideWith((ref) => AppScope.grup),
        activeGroupIdProvider.overrideWith((ref) => 'grp_jumat'),
        activeGroupStreamProvider.overrideWith(
          (ref) => Stream.value(sampleGroup),
        ),
        activeGroupSessionsStreamProvider.overrideWith(
          (ref) => Stream.value(sessions),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          );
        },
      ),
    );
  }

  group('Tahap H2 - Layar 62 Riwayat Grup & Filter (Rgrup1)', () {
    testWidgets(
      '1. Menampilkan Kartu Ringkasan Matahari, Filter Chips, dan 4 Kartu Date sesuai Rgrup1.dc.html',
      (tester) async {
        await tester.pumpWidget(buildTestApp(sessions: sampleSessions));
        await tester.pumpAndSettle();

        // Header & Scope Pill
        expect(find.text('Riwayat'), findsOneWidget);
        expect(find.text('Grup · Date Jumat'), findsOneWidget);

        // Kartu Ringkasan Matahari
        expect(find.text('Date Jumat · 4 date'), findsOneWidget);
        expect(find.text('2 lolos, 2 lewat'), findsOneWidget);
        expect(find.text('Rata-rata budget'), findsOneWidget);
        expect(find.text('Rp117.500'), findsOneWidget);

        // Chip Filter
        expect(find.text('Semua · 4'), findsOneWidget);
        expect(find.text('Lolos'), findsWidgets);
        expect(find.text('Lewat'), findsOneWidget);

        // Kartu Date
        expect(find.text('Raka · Roda Putar'), findsOneWidget);
        expect(find.text('Dina · Kocok Dadu'), findsOneWidget);
        expect(find.text('Kamu · Gacha Kapsul'), findsOneWidget);
        expect(find.text('Bima · Pilih Amplop'), findsOneWidget);
        expect(find.text('Lewat Rp12rb'), findsNWidgets(2));
      },
    );

    testWidgets(
      '2. Filter Lolos dan Lewat menyaring daftar kartu serta bertahan saat kembali dari detail',
      (tester) async {
        await tester.pumpWidget(buildTestApp(sessions: sampleSessions));
        await tester.pumpAndSettle();

        // Ketuk chip "Lewat"
        await tester.tap(find.text('Lewat'));
        await tester.pumpAndSettle();

        // Hanya sesi Lewat (Raka & Bima) yang tampil
        expect(find.text('Raka · Roda Putar'), findsOneWidget);
        expect(find.text('Bima · Pilih Amplop'), findsOneWidget);
        expect(find.text('Dina · Kocok Dadu'), findsNothing);
        expect(find.text('Kamu · Gacha Kapsul'), findsNothing);

        // Ketuk kartu pertama (sess_4) untuk masuk ke rute detail Layar 63
        await tester.tap(find.text('Raka · Roda Putar'));
        await tester.pumpAndSettle();

        expect(find.text('DETAIL_SESI:sess_4'), findsOneWidget);

        // Kembali ke Layar 62 -> filter "Lewat" tetap aktif
        await tester.tap(find.text('KEMBALI'));
        await tester.pumpAndSettle();

        expect(find.text('Raka · Roda Putar'), findsOneWidget);
        expect(find.text('Dina · Kocok Dadu'), findsNothing);
      },
    );

    testWidgets(
      '3. State kosong menampilkan "Belum ada date selesai"',
      (tester) async {
        await tester.pumpWidget(buildTestApp(sessions: const []));
        await tester.pumpAndSettle();

        expect(find.text('Belum ada date selesai'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Bebas overflow pada lebar 320dp dan 390dp dengan textScale 1.3',
      (tester) async {
        for (final width in [320.0, 390.0]) {
          await tester.binding.setSurfaceSize(Size(width, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            buildTestApp(
              sessions: sampleSessions,
              textScale: 1.3,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(GroupHistoryView), findsOneWidget);
        }
      },
    );
  });
}

