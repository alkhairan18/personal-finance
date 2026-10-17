enum ObligationStatus {
  paid,
  overdue,
  dueToday,
  upcoming,
  activeNoDueDate,
}

extension ObligationStatusX on ObligationStatus {
  String get label {
    switch (this) {
      case ObligationStatus.paid:
        return 'Lunas';
      case ObligationStatus.overdue:
        return 'Terlambat';
      case ObligationStatus.dueToday:
        return 'Hari Ini';
      case ObligationStatus.upcoming:
        return 'Akan Datang';
      case ObligationStatus.activeNoDueDate:
        return 'Aktif';
    }
  }
}

class ObligationStatusCalculator {
  const ObligationStatusCalculator._();

  static ObligationStatus deriveStatus({
    required int remainingAmount,
    required DateTime? dueDate,
    required DateTime today,
  }) {
    if (remainingAmount <= 0) {
      return ObligationStatus.paid;
    }
    if (dueDate == null) {
      return ObligationStatus.activeNoDueDate;
    }
    final normalizedDue = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final normalizedToday = DateTime(today.year, today.month, today.day);
    if (normalizedDue.isBefore(normalizedToday)) {
      return ObligationStatus.overdue;
    }
    if (normalizedDue.isAtSameMomentAs(normalizedToday)) {
      return ObligationStatus.dueToday;
    }
    return ObligationStatus.upcoming;
  }

  static ObligationStatus deriveFromIso({
    required int remainingAmount,
    required String? dueDateIso,
    DateTime? today,
  }) {
    DateTime? parsedDue;
    if (dueDateIso != null && dueDateIso.trim().isNotEmpty) {
      parsedDue = DateTime.tryParse(dueDateIso.trim());
    }
    return deriveStatus(
      remainingAmount: remainingAmount,
      dueDate: parsedDue,
      today: today ?? DateTime.now(),
    );
  }
}
