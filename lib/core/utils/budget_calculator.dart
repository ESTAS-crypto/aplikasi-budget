import 'package:flutter/material.dart';
import '../theme/putar_theme.dart';

enum BudgetStatus {
  safe,    // < 70% (Mint)
  warning, // 70% - 90% (Kuning / Matahari)
  danger,  // > 90% (Tomat)
}

class BudgetCalculator {
  BudgetCalculator._();

  static double getSpentPercentage({
    required int spent,
    required int budget,
  }) {
    if (budget <= 0) return 1.0;
    return spent / budget;
  }

  static BudgetStatus getStatus({
    required int spent,
    required int budget,
  }) {
    final ratio = getSpentPercentage(spent: spent, budget: budget);
    if (ratio < 0.70) {
      return BudgetStatus.safe;
    } else if (ratio <= 0.90) {
      return BudgetStatus.warning;
    } else {
      return BudgetStatus.danger;
    }
  }

  static Color getStatusColor({
    required int spent,
    required int budget,
    PutarTheme? theme,
  }) {
    final t = theme ?? PutarTheme.pasarMalam;
    final status = getStatus(spent: spent, budget: budget);
    switch (status) {
      case BudgetStatus.safe:
        return t.success;
      case BudgetStatus.warning:
        return t.warning;
      case BudgetStatus.danger:
        return t.danger;
    }
  }

  /// Mengecek apakah batas 80% terlewati
  static bool shouldShow80Warning({
    required int previousSpent,
    required int newSpent,
    required int budget,
  }) {
    if (budget <= 0) return false;
    final prevRatio = previousSpent / budget;
    final newRatio = newSpent / budget;
    return prevRatio < 0.80 && newRatio >= 0.80 && newRatio <= 1.0;
  }

  /// Mengecek apakah melewati 100% budget
  static bool isOverbudget({
    required int spent,
    required int budget,
  }) {
    return spent > budget;
  }
}
