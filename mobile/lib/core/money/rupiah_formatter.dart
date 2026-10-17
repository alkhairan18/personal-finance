class RupiahFormatter {
  const RupiahFormatter._();

  static String format(int amount) {
    final isNegative = amount < 0;
    final absDigits = formatNumberOnly(amount.abs());
    return isNegative ? '-Rp $absDigits' : 'Rp $absDigits';
  }

  static String formatNumberOnly(int amount) {
    final raw = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final indexFromEnd = raw.length - i;
      buffer.write(raw[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }

  static int parseDigits(String raw) {
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return 0;
    }
    return int.tryParse(digitsOnly) ?? 0;
  }
}
