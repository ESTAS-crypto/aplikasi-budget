import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/games/game_engine.dart';
import '../splash/splash_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../games/games_hub_screen.dart';
import '../games/dice_screen.dart';
import '../games/capsule_screen.dart';
import '../games/envelope_screen.dart';
import '../games/coin_screen.dart';
import '../wheel/wheel_screen.dart';
import '../wheel/custom_wheel_screen.dart';
import '../wheel/brand_system_screen.dart';
import '../date/active_date_screen.dart';
import '../date/date_result_screen.dart';
import '../history/history_screen.dart';
import '../group/screens/join_or_create_group_screen.dart';
import '../group/screens/group_invite_screen.dart';
import '../group/screens/group_activity_screen.dart';
import '../group/screens/group_date_detail_screen.dart';
import '../group/screens/group_date_result_screen.dart';
import '../group/screens/group_budget_settings_screen.dart';
import '../group/screens/group_dice_screen.dart';
import '../group/screens/group_capsule_screen.dart';
import '../group/screens/group_envelope_screen.dart';
import '../group/screens/group_coin_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../settings/screens/theme_selection_screen.dart';
import '../notifications/screens/notification_debug_screen.dart';
import '../../core/painters/sticker_icons.dart';
import '../../core/theme/putar_theme.dart';
import '../../core/widgets/sticker_button.dart';
import 'bottom_nav_bar.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

CustomTransitionPage<void> _buildCustomTransitionPage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Transisi custom: slide (dari kanan sedikit) + fade 250ms
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0.08, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeIn,
      );

      return SlideTransition(
        position: slideAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: child,
        ),
      );
    },
  );
}

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  errorBuilder: (context, state) {
    final t = context.putarTheme;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          'Halaman Tidak Ditemukan',
          style: t.titleMedium.copyWith(color: t.ink),
        ),
        backgroundColor: t.bg,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CustomPaint(
                  painter: CustomWarningIconPainter(
                    color: t.ink,
                    markColor: t.danger,
                    strokeWidth: t.borderWidth,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Oops! Halaman Tidak Ditemukan',
                style: t.titleMedium.copyWith(color: t.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Rute "${state.uri.path}" tidak tersedia.',
                style: t.bodySmall.copyWith(color: t.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              StickerButton(
                text: 'Kembali ke Roda',
                backgroundColor: t.success,
                onPressed: () => context.go('/roda'),
              ),
            ],
          ),
        ),
      ),
    );
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) => _buildCustomTransitionPage(
        context: context,
        state: state,
        child: const OnboardingScreen(),
      ),
    ),
    GoRoute(
      path: '/custom-wheel',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        final gameParam = state.uri.queryParameters['game'];
        final groupId = state.uri.queryParameters['groupId'];
        GameType type = GameType.wheel;
        if (gameParam == 'capsule') {
          type = GameType.capsule;
        } else if (gameParam == 'envelope') {
          type = GameType.envelope;
        }
        return _buildCustomTransitionPage(
          context: context,
          state: state,
          child: CustomWheelScreen(
            gameType: type,
            groupId: groupId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/brand-system',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildCustomTransitionPage(
        context: context,
        state: state,
        child: const BrandSystemScreen(),
      ),
    ),
    GoRoute(
      path: '/date-result/:id',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
        return _buildCustomTransitionPage(
          context: context,
          state: state,
          child: DateResultScreen(dateId: id),
        );
      },
    ),
    GoRoute(
      path: '/group/date-result',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        final qp = state.uri.queryParameters;
        final groupName = qp['groupName'] ?? 'Grup';
        final budget = int.tryParse(qp['budget'] ?? '0') ?? 0;
        final totalSpent = int.tryParse(qp['totalSpent'] ?? '0') ?? 0;
        final itemCount = int.tryParse(qp['itemCount'] ?? '0') ?? 0;
        final sessionDateMs = int.tryParse(qp['sessionDateMs'] ?? '');
        final endedAtMs = int.tryParse(qp['endedAtMs'] ?? '');
        return _buildCustomTransitionPage(
          context: context,
          state: state,
          child: GroupDateResultScreen(
            groupName: groupName,
            budget: budget,
            totalSpent: totalSpent,
            itemCount: itemCount,
            groupId: qp['gid'],
            sessionId: qp['sessionId'],
            budgetByName: qp['budgetByName'],
            budgetGame: qp['budgetGame'],
            endedByName: qp['endedByName'],
            endedByUid: qp['endedByUid'],
            sessionDate: sessionDateMs != null
                ? DateTime.fromMillisecondsSinceEpoch(sessionDateMs)
                : null,
            endedAt: endedAtMs != null
                ? DateTime.fromMillisecondsSinceEpoch(endedAtMs)
                : null,
          ),
        );
      },
    ),
    GoRoute(
      path: '/group/join-or-create',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildCustomTransitionPage(
        context: context,
        state: state,
        child: const JoinOrCreateGroupScreen(),
      ),
    ),
    GoRoute(
      path: '/group/invite/:gid',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        final gid = state.pathParameters['gid'] ?? '';
        return _buildCustomTransitionPage(
          context: context,
          state: state,
          child: GroupInviteScreen(groupId: gid),
        );
      },
    ),
    GoRoute(
      path: '/group/budget-settings/:gid',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        final gid = state.pathParameters['gid'] ?? '';
        return _buildCustomTransitionPage(
          context: context,
          state: state,
          child: GroupBudgetSettingsScreen(groupId: gid),
        );
      },
    ),
    GoRoute(
      path: '/group/note-add/:gid/:sessionId',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildCustomTransitionPage(
        context: context,
        state: state,
        child: const ActiveDateScreen(autoOpenAdd: true),
      ),
    ),
    GoRoute(
      path: '/group/note-add/:gid',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildCustomTransitionPage(
        context: context,
        state: state,
        child: const ActiveDateScreen(autoOpenAdd: true),
      ),
    ),
    GoRoute(
      path: '/group/activity',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildCustomTransitionPage(
        context: context,
        state: state,
        child: const GroupActivityScreen(),
      ),
    ),
    GoRoute(
      path: '/group/history/:gid/:sessionId',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        final gid = state.pathParameters['gid'] ?? '';
        final sessionId = state.pathParameters['sessionId'] ?? '';
        final tabParam = state.uri.queryParameters['tab'];
        GroupDateDetailTab initialTab = GroupDateDetailTab.ringkasan;
        if (tabParam == 'catatan' || tabParam == 'notes') {
          initialTab = GroupDateDetailTab.catatan;
        } else if (tabParam == 'linimasa' || tabParam == 'timeline') {
          initialTab = GroupDateDetailTab.linimasa;
        }
        return _buildCustomTransitionPage(
          context: context,
          state: state,
          child: GroupDateDetailScreen(
            groupId: gid,
            sessionId: sessionId,
            initialTab: initialTab,
          ),
        );
      },
    ),
    GoRoute(
      path: '/group/dice',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildCustomTransitionPage(
        context: context,
        state: state,
        child: const GroupDiceScreen(),
      ),
    ),
    GoRoute(
      path: '/group/capsule',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildCustomTransitionPage(
        context: context,
        state: state,
        child: const GroupCapsuleScreen(),
      ),
    ),
    GoRoute(
      path: '/group/envelope',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildCustomTransitionPage(
        context: context,
        state: state,
        child: const GroupEnvelopeScreen(),
      ),
    ),
    GoRoute(
      path: '/group/coin',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildCustomTransitionPage(
        context: context,
        state: state,
        child: const GroupCoinScreen(),
      ),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        final tabParam = state.uri.queryParameters['tab'];
        final initialTab = (tabParam == 'grup' || tabParam == 'group') ? 1 : 0;
        return _buildCustomTransitionPage(
          context: context,
          state: state,
          child: SettingsScreen(initialTab: initialTab),
        );
      },
    ),
    GoRoute(
      path: '/themes',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildCustomTransitionPage(
        context: context,
        state: state,
        child: const ThemeSelectionScreen(),
      ),
    ),
    GoRoute(
      path: '/group/notifications',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildCustomTransitionPage(
        context: context,
        state: state,
        child: const SettingsScreen(initialTab: 1),
      ),
    ),
    GoRoute(
      path: '/debug/notifications',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildCustomTransitionPage(
        context: context,
        state: state,
        child: const NotificationDebugScreen(),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: BottomNavBar(navigationShell: navigationShell),
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => _buildCustomTransitionPage(
                context: context,
                state: state,
                child: const GamesHubScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'wheel',
                  pageBuilder: (context, state) => _buildCustomTransitionPage(
                    context: context,
                    state: state,
                    child: const WheelScreen(),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/wheel-game',
              pageBuilder: (context, state) => _buildCustomTransitionPage(
                context: context,
                state: state,
                child: const WheelScreen(),
              ),
            ),
            GoRoute(
              path: '/dice-game',
              pageBuilder: (context, state) => _buildCustomTransitionPage(
                context: context,
                state: state,
                child: const DiceScreen(),
              ),
            ),
            GoRoute(
              path: '/capsule-game',
              pageBuilder: (context, state) => _buildCustomTransitionPage(
                context: context,
                state: state,
                child: const CapsuleScreen(),
              ),
            ),
            GoRoute(
              path: '/envelope-game',
              pageBuilder: (context, state) => _buildCustomTransitionPage(
                context: context,
                state: state,
                child: const EnvelopeScreen(),
              ),
            ),
            GoRoute(
              path: '/coin-game',
              pageBuilder: (context, state) => _buildCustomTransitionPage(
                context: context,
                state: state,
                child: const CoinScreen(),
              ),
            ),
            GoRoute(
              path: '/roda',
              pageBuilder: (context, state) => _buildCustomTransitionPage(
                context: context,
                state: state,
                child: const WheelScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/catatan',
              pageBuilder: (context, state) {
                final openAdd = state.uri.queryParameters['openAdd'] == 'true';
                return _buildCustomTransitionPage(
                  context: context,
                  state: state,
                  child: ActiveDateScreen(autoOpenAdd: openAdd),
                );
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/riwayat',
              pageBuilder: (context, state) => _buildCustomTransitionPage(
                context: context,
                state: state,
                child: const HistoryScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
