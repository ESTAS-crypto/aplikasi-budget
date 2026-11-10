import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database.dart';
import '../core/utils/streak_calculator.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Stream nominal slot roda
final wheelSlotsStreamProvider = StreamProvider<List<WheelSlot>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchWheelSlots();
});

/// Stream date yang sedang aktif (Lagi ngedate)
final activeDateStreamProvider = StreamProvider<DateRecord?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchActiveDate();
});

/// Stream item belanja pada date yang sedang aktif
final activeDateItemsStreamProvider = StreamProvider<List<DateItemRecord>>((ref) {
  final activeDateAsync = ref.watch(activeDateStreamProvider);
  final activeDate = activeDateAsync.value;
  if (activeDate == null) {
    return Stream.value([]);
  }
  final db = ref.watch(databaseProvider);
  return db.watchItemsForDate(activeDate.id);
});

/// Stream semua date yang sudah selesai untuk riwayat
final finishedDatesStreamProvider = StreamProvider<List<DateRecord>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchFinishedDates();
});

/// Perhitungan streak mingguan lolos berturut-turut
final currentStreakProvider = Provider<int>((ref) {
  final finishedDatesAsync = ref.watch(finishedDatesStreamProvider);
  final dates = finishedDatesAsync.value ?? [];
  final passedList = dates.map((d) => d.isPassed ?? false).toList();
  return StreakCalculator.calculateStreak(passedList);
});

/// Total date ke-N (jumlah total date + 1)
final currentRoundNumberProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  final count = await db.countTotalDates();
  return count + 1;
});
