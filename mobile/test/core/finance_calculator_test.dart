import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/finance/installment_calculator.dart';
import 'package:personal_finance/core/finance/obligation_status.dart';
import 'package:personal_finance/core/money/rupiah_formatter.dart';

void main() {
  group('InstallmentCalculator', () {
    test('7 monthly installments of Rp 6.000.000 put remainder on 7th term', () {
      final terms = InstallmentCalculator.generateSchedule(
        totalAmount: 6000000,
        count: 7,
        frequency: 'monthly',
        startDate: DateTime(2026, 8, 17),
      );
      expect(terms.length, 7);
      for (var i = 0; i < 6; i++) {
        expect(terms[i].installmentNumber, i + 1);
        expect(terms[i].plannedAmount, 857142);
      }
      expect(terms[6].installmentNumber, 7);
      expect(terms[6].plannedAmount, 857148);
      expect(terms.fold<int>(0, (sum, t) => sum + t.plannedAmount), 6000000);
      expect(terms[0].dueDate, DateTime(2026, 8, 17));
      expect(terms[1].dueDate, DateTime(2026, 9, 17));
      expect(terms[6].dueDate, DateTime(2027, 2, 17));
    });

    test('weekly schedule increments by 7 days per term', () {
      final terms = InstallmentCalculator.generateSchedule(
        totalAmount: 100000,
        count: 3,
        frequency: 'weekly',
        startDate: DateTime(2026, 10, 1),
      );
      expect(terms.map((t) => t.plannedAmount).toList(), [33333, 33333, 33334]);
      expect(terms[0].dueDate, DateTime(2026, 10, 1));
      expect(terms[1].dueDate, DateTime(2026, 10, 8));
      expect(terms[2].dueDate, DateTime(2026, 10, 15));
    });
  });

  group('ObligationStatusCalculator', () {
    test('deriveStatus returns paid when remaining is 0 even if dueDate passed', () {
      final status = ObligationStatusCalculator.deriveStatus(
        remainingAmount: 0,
        dueDate: DateTime(2026, 10, 1),
        today: DateTime(2026, 10, 17),
      );
      expect(status, ObligationStatus.paid);
    });

    test('deriveStatus distinguishes overdue, dueToday, upcoming, and activeNoDueDate', () {
      final today = DateTime(2026, 10, 17);
      expect(
        ObligationStatusCalculator.deriveStatus(
          remainingAmount: 50000,
          dueDate: DateTime(2026, 10, 16),
          today: today,
        ),
        ObligationStatus.overdue,
      );
      expect(
        ObligationStatusCalculator.deriveStatus(
          remainingAmount: 50000,
          dueDate: DateTime(2026, 10, 17),
          today: today,
        ),
        ObligationStatus.dueToday,
      );
      expect(
        ObligationStatusCalculator.deriveStatus(
          remainingAmount: 50000,
          dueDate: DateTime(2026, 10, 20),
          today: today,
        ),
        ObligationStatus.upcoming,
      );
      expect(
        ObligationStatusCalculator.deriveStatus(
          remainingAmount: 50000,
          dueDate: null,
          today: today,
        ),
        ObligationStatus.activeNoDueDate,
      );
    });
  });

  group('RupiahFormatter', () {
    test('formats integer Rupiah with dot thousands separators and no decimals', () {
      expect(RupiahFormatter.format(0), 'Rp 0');
      expect(RupiahFormatter.format(45000), 'Rp 45.000');
      expect(RupiahFormatter.format(1250000), 'Rp 1.250.000');
      expect(RupiahFormatter.format(-857142), '-Rp 857.142');
    });

    test('parses digit string into integer Rupiah safely', () {
      expect(RupiahFormatter.parseDigits('Rp 45.000'), 45000);
      expect(RupiahFormatter.parseDigits(''), 0);
    });
  });
}
