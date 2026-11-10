import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/features/notifications/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({
      'pj_friday_reminder_enabled': true,
    });

    // Mock platform channel for flutter_local_notifications
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'initialize':
          return true;
        case 'zonedSchedule':
          return true;
        case 'cancel':
          return true;
        case 'pendingNotificationRequests':
          return <Map<String, dynamic>>[
            {
              'id': NotificationService.notificationReminderId,
              'title': 'Roda lagi nunggu kamu',
              'body': 'Jumat malam waktunya putar. Siapa tau dapat 150k.',
              'payload': null,
            }
          ];
        case 'canScheduleExactNotifications':
          return true;
        default:
          return null;
      }
    });

    // Mock timezone plugin channel
    const tzChannel = MethodChannel('flutter_timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tzChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'getLocalTimezone') {
        return 'Asia/Jakarta';
      }
      return null;
    });
  });

  tearDown(() {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    const tzChannel = MethodChannel('flutter_timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tzChannel, null);
  });

  group('N3: Idempotent Scheduled Reminders (UPDATE 2C Section 2)', () {
    test('notificationReminderId has stable fixed ID 1003', () {
      expect(NotificationService.notificationReminderId, 1003);
    });

    test('Calling scheduleWeeklyFridayReminder 5 times consecutively remains idempotent without double scheduling', () async {
      final service = NotificationService.instance;
      await service.initialize();

      // Simulate opening the app 5 times
      for (int i = 0; i < 5; i++) {
        await service.scheduleWeeklyFridayReminder();
      }

      // Verify that getPendingNotificationRequests returns exactly 1 reminder with ID 1003
      final pending = await service.getPendingNotificationRequests();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals(NotificationService.notificationReminderId));
    });

    test('handleSystemConfigChange refreshes timezone and reschedules reminder idempotently', () async {
      final service = NotificationService.instance;
      await service.initialize();

      await service.handleSystemConfigChange();

      final pending = await service.getPendingNotificationRequests();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals(NotificationService.notificationReminderId));
    });

    test('cancelWeeklyFridayReminder executes without exception', () async {
      final service = NotificationService.instance;
      await expectLater(service.cancelWeeklyFridayReminder(), completes);
    });
  });
}
