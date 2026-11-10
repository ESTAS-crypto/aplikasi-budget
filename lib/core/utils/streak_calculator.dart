class StreakCalculator {
  StreakCalculator._();

  /// Menghitung streak berturut-turut yang lolos dari daftar date yang diurutkan dari yang terbaru
  static int calculateStreak(List<bool> isPassedListOrderedNewestFirst) {
    int streak = 0;
    for (final passed in isPassedListOrderedNewestFirst) {
      if (passed) {
        streak++;
      } else {
        break; // Berhenti saat menemui yang lewat
      }
    }
    return streak;
  }
}
