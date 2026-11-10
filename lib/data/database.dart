import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Tabel slot nominal pada roda putar
class WheelSlots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amount => integer()();
  IntColumn get orderIndex => integer()();
}

/// Tabel rekaman sesi kencan (Date)
class DateRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get budget => integer()();
  TextColumn get status => text()(); // 'active', 'finished'
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  BoolColumn get isPassed => boolean().nullable()();
}

/// Tabel item belanja/jajan pada suatu date
class DateItemRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dateId => integer()();
  TextColumn get name => text()();
  IntColumn get price => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [WheelSlots, DateRecords, DateItemRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // Masukkan 8 nominal slot default: 20k, 40k, 60k, 100k, 30k, 150k, 50k, 80k
          final defaultAmounts = [20000, 40000, 60000, 100000, 30000, 150000, 50000, 80000];
          for (int i = 0; i < defaultAmounts.length; i++) {
            await into(wheelSlots).insert(
              WheelSlotsCompanion.insert(
                amount: defaultAmounts[i],
                orderIndex: i,
              ),
            );
          }
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Siap untuk migrasi skema masa depan
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'putar_jajan_db');
  }

  // --- Wheel Slots Queries ---
  Stream<List<WheelSlot>> watchWheelSlots() {
    return (select(wheelSlots)..orderBy([(t) => OrderingTerm(expression: t.orderIndex)])).watch();
  }

  Future<List<WheelSlot>> getWheelSlots() {
    return (select(wheelSlots)..orderBy([(t) => OrderingTerm(expression: t.orderIndex)])).get();
  }

  Future<void> replaceWheelSlots(List<int> amounts) async {
    await transaction(() async {
      await delete(wheelSlots).go();
      for (int i = 0; i < amounts.length; i++) {
        await into(wheelSlots).insert(
          WheelSlotsCompanion.insert(
            amount: amounts[i],
            orderIndex: i,
          ),
        );
      }
    });
  }

  // --- Date Queries ---
  Future<int> createDate(int budget) async {
    return transaction(() async {
      // Pastikan tidak ada date aktif ganda yang bertumpuk
      await (update(dateRecords)..where((t) => t.status.equals('active')))
          .write(const DateRecordsCompanion(status: Value('finished'), isPassed: Value(false)));

      return into(dateRecords).insert(
        DateRecordsCompanion.insert(
          budget: budget,
          status: 'active',
          startedAt: DateTime.now(),
        ),
      );
    });
  }

  Future<DateRecord?> getActiveDate() {
    return (select(dateRecords)
          ..where((t) => t.status.equals('active'))
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<DateRecord?> watchActiveDate() {
    return (select(dateRecords)
          ..where((t) => t.status.equals('active'))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<DateRecord?> getDateById(int id) async {
    return (select(dateRecords)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<List<DateRecord>> watchFinishedDates() {
    return (select(dateRecords)
          ..where((t) => t.status.equals('finished'))
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<DateRecord>> getFinishedDates() {
    return (select(dateRecords)
          ..where((t) => t.status.equals('finished'))
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<int> countTotalDates() async {
    final countExp = dateRecords.id.count();
    final query = selectOnly(dateRecords)..addColumns([countExp]);
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  Future<void> finishDate(int dateId, bool isPassed) async {
    await (update(dateRecords)..where((t) => t.id.equals(dateId))).write(
      DateRecordsCompanion(
        status: const Value('finished'),
        finishedAt: Value(DateTime.now()),
        isPassed: Value(isPassed),
      ),
    );
  }

  // --- Date Items Queries ---
  Stream<List<DateItemRecord>> watchItemsForDate(int dateId) {
    return (select(dateItemRecords)
          ..where((t) => t.dateId.equals(dateId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<List<DateItemRecord>> getItemsForDate(int dateId) {
    return (select(dateItemRecords)
          ..where((t) => t.dateId.equals(dateId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .get();
  }

  Future<int> addItem({
    required int dateId,
    required String name,
    required int price,
  }) async {
    return into(dateItemRecords).insert(
      DateItemRecordsCompanion.insert(
        dateId: dateId,
        name: name,
        price: price,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> removeItem(int itemId) async {
    await (delete(dateItemRecords)..where((t) => t.id.equals(itemId))).go();
  }
}
