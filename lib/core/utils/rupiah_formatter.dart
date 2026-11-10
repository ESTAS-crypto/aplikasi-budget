import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class RupiahFormatter {
  RupiahFormatter._();

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  /// Format angka ke format resmi: "Rp100.000"
  static String format(int amount) {
    return _formatter.format(amount).replaceAll(' ', '');
  }

  /// Format angka ke format ringkas kartu/irisan: "100k" atau "54rb"
  static String formatCompact(int amount) {
    if (amount >= 1000000) {
      final val = amount / 1000000;
      return val % 1 == 0 ? '${val.toInt()}jt' : '${val.toStringAsFixed(1)}jt';
    } else if (amount >= 1000) {
      final val = amount / 1000;
      return val % 1 == 0 ? '${val.toInt()}k' : '${val.toStringAsFixed(1)}k';
    }
    return amount.toString();
  }

  /// Format untuk badge riwayat: "54rb", "141rb", "12rb"
  static String formatRb(int amount) {
    if (amount >= 1000) {
      final val = (amount / 1000).round();
      return '${val}rb';
    }
    return amount.toString();
  }

  /// Parse string input ke integer (mendukung pemisah titik)
  static int parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return 0;
    return int.tryParse(cleaned) ?? 0;
  }
}

/// Formatter input teks otomatis menambahkan titik ribuan (misal: 20000 -> 20.000)
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final int maxDigits;

  const ThousandsSeparatorInputFormatter({this.maxDigits = 9}); // maks 999.999.999

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Ambil angka saja
    String cleanDigits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanDigits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Hapus leading zero berlebih
    if (cleanDigits.length > 1 && cleanDigits.startsWith('0')) {
      cleanDigits = cleanDigits.replaceFirst(RegExp(r'^0+'), '');
      if (cleanDigits.isEmpty) cleanDigits = '0';
    }

    // Batasi panjang digit
    if (cleanDigits.length > maxDigits) {
      cleanDigits = cleanDigits.substring(0, maxDigits);
    }

    // Format dengan titik setiap 3 digit dari kanan
    final buffer = StringBuffer();
    final len = cleanDigits.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(cleanDigits[i]);
    }
    final formatted = buffer.toString();

    // Hitung posisi kursor secara presisi
    int digitsBeforeCursor = 0;
    final int oldCursor = newValue.selection.end.clamp(0, newValue.text.length);
    for (int i = 0; i < oldCursor; i++) {
      if (RegExp(r'\d').hasMatch(newValue.text[i])) {
        digitsBeforeCursor++;
      }
    }

    int newCursor = 0;
    int digitCount = 0;
    while (newCursor < formatted.length && digitCount < digitsBeforeCursor) {
      if (RegExp(r'\d').hasMatch(formatted[newCursor])) {
        digitCount++;
      }
      newCursor++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: newCursor.clamp(0, formatted.length),
      ),
    );
  }
}
