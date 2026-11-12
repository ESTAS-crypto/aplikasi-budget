import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('N2 Guard Test: Single Door Architecture (NotificationCoordinator)', () {
    test('No screen or listener directly calls InAppBanner.show or showGroupActivityNotification', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final violations = <String>[];

      final files = libDir.listSync(recursive: true).whereType<File>().where(
            (f) => f.path.endsWith('.dart'),
          );

      for (final file in files) {
        final path = file.path.replaceAll(r'\', '/');

        // Whitelisted files that are part of the notification infrastructure
        final isCoordinator = path.contains('core/notifications/coordinator/notification_coordinator.dart');
        final isBannerWidget = path.contains('core/group/widgets/in_app_banner.dart') ||
            path.contains('core/widgets/in_app_banner.dart');
        final isNotificationService = path.contains('features/notifications/notification_service.dart');
        final isSettingsDemo = path.contains('features/settings/screens/settings_screen.dart');
        final isNotesView = path.contains('features/group/screens/group_notes_view.dart');

        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          final lineNum = i + 1;

          // Check direct call to showGroupActivityNotification
          if (line.contains('showGroupActivityNotification') && !isNotificationService) {
            violations.add('$path:$lineNum -> calls showGroupActivityNotification directly');
          }

          // Check direct call to InAppBanner.show outside coordinator, banner widget, or settings demo/notes view
          if (line.contains('InAppBanner.show') && !isCoordinator && !isBannerWidget && !isSettingsDemo && !isNotesView) {
            violations.add('$path:$lineNum -> calls InAppBanner.show directly (must use NotificationCoordinator)');
          }

          // Check direct call to _plugin.show outside NotificationService
          if (line.contains('_plugin.show') && !isNotificationService) {
            violations.add('$path:$lineNum -> calls _plugin.show directly outside NotificationService');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Violations found! All notifications must go through NotificationCoordinator:\n${violations.join("\n")}',
      );
    });

    test('group_realtime_listener routes group events via notificationCoordinatorProvider', () {
      final listenerFile = File('lib/core/group/widgets/group_realtime_listener.dart');
      expect(listenerFile.existsSync(), isTrue);

      final content = listenerFile.readAsStringSync();
      expect(
        content.contains('notificationCoordinatorProvider'),
        isTrue,
        reason: 'group_realtime_listener must use notificationCoordinatorProvider',
      );
      expect(
        content.contains('NotificationIntent.groupEvent'),
        isTrue,
        reason: 'group_realtime_listener must create NotificationIntent.groupEvent',
      );
      expect(
        content.contains('showGroupActivityNotification'),
        isFalse,
        reason: 'group_realtime_listener must NOT call showGroupActivityNotification directly',
      );
    });
  });
}

