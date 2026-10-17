class PlannedInstallmentTerm {
  final int installmentNumber;
  final DateTime dueDate;
  final int plannedAmount;

  const PlannedInstallmentTerm({
    required this.installmentNumber,
    required this.dueDate,
    required this.plannedAmount,
  });

  String get dueDateIso =>
      '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
}

class InstallmentCalculator {
  const InstallmentCalculator._();

  static List<PlannedInstallmentTerm> generateSchedule({
    required int totalAmount,
    required int count,
    required String frequency,
    required DateTime startDate,
  }) {
    if (totalAmount <= 0 || count <= 0) {
      throw ArgumentError('totalAmount and count must be greater than zero');
    }

    final baseAmount = totalAmount ~/ count;
    final remainder = totalAmount % count;
    final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);

    final terms = <PlannedInstallmentTerm>[];
    for (var i = 1; i <= count; i++) {
      final DateTime dueDate;
      if (frequency == 'weekly') {
        dueDate = normalizedStart.add(Duration(days: (i - 1) * 7));
      } else {
        dueDate = _addMonthsNoOverflow(normalizedStart, i - 1);
      }

      final plannedAmount = (i == count) ? (baseAmount + remainder) : baseAmount;
      terms.add(
        PlannedInstallmentTerm(
          installmentNumber: i,
          dueDate: dueDate,
          plannedAmount: plannedAmount,
        ),
      );
    }

    return terms;
  }

  static DateTime _addMonthsNoOverflow(DateTime start, int monthsToAdd) {
    final totalMonths = (start.year * 12) + (start.month - 1) + monthsToAdd;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = (totalMonths % 12) + 1;
    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final clampedDay = start.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : start.day;
    return DateTime(targetYear, targetMonth, clampedDay);
  }
}
