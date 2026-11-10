/// Helper pemformat tanggal Bahasa Indonesia murni tanpa ketergantungan paket intl locale table
class IndonesianDateFormatter {
  static const List<String> days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  /// Mengembalikan nama hari Bahasa Indonesia ('Senin' s.d. 'Minggu')
  static String dayName(DateTime date) {
    final idx = (date.weekday - 1).clamp(0, 6);
    return days[idx];
  }

  /// Mengembalikan string seperti 'Rabu malam'
  static String dayWithNight(DateTime date) {
    return '${dayName(date)} malam';
  }

  /// Mengembalikan string seperti 'Jumat, 24 Okt'
  static String fullDayAndDate(DateTime date) {
    final dName = dayName(date);
    final mName = months[(date.month - 1).clamp(0, 11)];
    return '$dName, ${date.day} $mName';
  }
}
