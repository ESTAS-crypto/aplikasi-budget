import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/games/game_engine.dart';
import 'database.dart';
import 'database_provider.dart';

class GamePoolRepository {
  static const String _keyCapsulePool = 'pool_capsule';
  static const String _keyEnvelopePool = 'pool_envelope';
  static const String _keyDiceMultiplier = 'dice_multiplier';
  static const String _keyDiceCount = 'dice_count';
  static const String _keyCoinBaseAmount = 'coin_base_amount';

  static const List<int> defaultWheelPool = [
    20000, 40000, 60000, 100000, 30000, 150000, 50000, 80000
  ];

  static const List<int> defaultCapsulePool = [
    20000, 30000, 40000, 50000, 60000, 80000, 100000, 150000
  ];

  static const List<int> defaultEnvelopePool = [
    20000, 30000, 40000, 50000, 60000, 80000, 100000, 150000
  ];

  static const List<int> defaultCoinPool = [CoinGameEngine.defaultBaseAmount];

  Future<List<int>> getPool(GameType type, AppDatabase db) async {
    switch (type) {
      case GameType.wheel:
        final slots = await db.getWheelSlots();
        if (slots.isEmpty) return defaultWheelPool;
        return slots.map((s) => s.amount).toList();
      case GameType.capsule:
        final sp = await SharedPreferences.getInstance();
        final raw = sp.getString(_keyCapsulePool);
        if (raw == null) return defaultCapsulePool;
        try {
          final List<dynamic> list = jsonDecode(raw);
          final result = list.map((e) => (e as num).toInt()).toList();
          return result.isNotEmpty ? result : defaultCapsulePool;
        } catch (_) {
          return defaultCapsulePool;
        }
      case GameType.envelope:
        final sp = await SharedPreferences.getInstance();
        final raw = sp.getString(_keyEnvelopePool);
        if (raw == null) return defaultEnvelopePool;
        try {
          final List<dynamic> list = jsonDecode(raw);
          final result = list.map((e) => (e as num).toInt()).toList();
          return result.isNotEmpty ? result : defaultEnvelopePool;
        } catch (_) {
          return defaultEnvelopePool;
        }
      case GameType.coin:
        final base = await getCoinBaseAmount();
        return [base];
      case GameType.dice:
        return defaultWheelPool;
    }
  }

  Future<void> savePool(GameType type, List<int> amounts, AppDatabase db) async {
    switch (type) {
      case GameType.wheel:
        await db.replaceWheelSlots(amounts);
        break;
      case GameType.capsule:
        final sp = await SharedPreferences.getInstance();
        await sp.setString(_keyCapsulePool, jsonEncode(amounts));
        break;
      case GameType.envelope:
        final sp = await SharedPreferences.getInstance();
        await sp.setString(_keyEnvelopePool, jsonEncode(amounts));
        break;
      case GameType.coin:
        if (amounts.isNotEmpty) {
          await setCoinBaseAmount(amounts.first);
        }
        break;
      case GameType.dice:
        break;
    }
  }

  Future<int> getCoinBaseAmount() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_keyCoinBaseAmount) ?? CoinGameEngine.defaultBaseAmount;
  }

  Future<void> setCoinBaseAmount(int amount) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_keyCoinBaseAmount, amount);
  }

  Future<int> getDiceMultiplier() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_keyDiceMultiplier) ?? 10000;
  }

  Future<void> setDiceMultiplier(int multiplier) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_keyDiceMultiplier, multiplier);
  }

  Future<int> getDiceCount() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_keyDiceCount) ?? 2;
  }

  Future<void> setDiceCount(int count) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_keyDiceCount, count);
  }
}

final gamePoolRepositoryProvider = Provider<GamePoolRepository>((ref) {
  return GamePoolRepository();
});

final poolStreamProvider = StreamProvider.family<List<int>, GameType>((ref, type) async* {
  final repo = ref.watch(gamePoolRepositoryProvider);
  final db = ref.watch(databaseProvider);

  if (type == GameType.wheel) {
    yield* db.watchWheelSlots().map((slots) => slots.map((s) => s.amount).toList());
  } else {
    final pool = await repo.getPool(type, db);
    yield pool;
  }
});

