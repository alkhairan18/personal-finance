import 'package:flutter/services.dart';

class RupiahFormatter {
  const RupiahFormatter._();

  static const List<String> _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const List<String> _shortMonthNames = [
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

  static String formatMonthYear(String yearMonth) {
    final parts = yearMonth.trim().split('-');
    if (parts.length < 2) return yearMonth;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return yearMonth;
    }
    return '${_monthNames[month - 1]} $year';
  }

  static String formatIsoDate(String isoDate) {
    final clean = isoDate.trim();
    if (clean.length < 10) return clean;
    final parts = clean.substring(0, 10).split('-');
    if (parts.length != 3) return clean;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null || month < 1 || month > 12) {
      return clean;
    }
    return '$day ${_shortMonthNames[month - 1]} $year';
  }
}

class RupiahInputFormatter extends TextInputFormatter {
  const RupiahInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final parsed = int.tryParse(digitsOnly) ?? 0;
    if (parsed == 0) {
      return const TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );
    }
    final formatted = RupiahFormatter.formatNumberOnly(parsed);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
