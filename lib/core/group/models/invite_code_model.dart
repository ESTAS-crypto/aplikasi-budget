import 'dart:math';

/// Generator kode undangan 6 karakter unik tanpa karakter membingungkan (tanpa 0, O, 1, I, L)
class InviteCodeGenerator {
  InviteCodeGenerator._();

  /// Alfabet 31 karakter aman tanpa karakter mirip/membingungkan
  static const String safeAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

  /// Menghasilkan kode undangan 6 karakter uppercase acak dengan Random.secure
  static String generate([Random? rng]) {
    final random = rng ?? Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < 6; i++) {
      final index = random.nextInt(safeAlphabet.length);
      buffer.write(safeAlphabet[index]);
    }
    return buffer.toString();
  }

  /// Menormalkan input kode (trim & uppercase)
  static String normalize(String code) => code.trim().toUpperCase();

  /// Validasi format kode (6 karakter dan hanya dari safe alphabet)
  static bool isValidFormat(String code) => isValid(code);

  /// Validasi apakah kode memenuhi syarat (6 karakter, hanya alfabet aman, case-insensitive)
  static bool isValid(String code) {
    final clean = normalize(code);
    if (clean.length != 6) return false;
    for (int i = 0; i < clean.length; i++) {
      if (!safeAlphabet.contains(clean[i])) {
        return false;
      }
    }
    return true;
  }
}

/// Model Invite Code di Firestore /inviteCodes/{code}
class InviteCodeModel {
  final String code;
  final String gid;
  final DateTime createdAt;

  const InviteCodeModel({
    required this.code,
    required this.gid,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'gid': gid,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory InviteCodeModel.fromMap(String code, Map<String, dynamic> map) {
    return InviteCodeModel(
      code: code,
      gid: map['gid'] as String? ?? '',
      createdAt: map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }
}

