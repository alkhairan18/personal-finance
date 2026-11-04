import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/money/rupiah_formatter.dart';

class PdfReportGenerator {
  const PdfReportGenerator._();

  /// Normalizes common punctuation and strips non-ASCII characters (emojis,
  /// non-Latin glyphs) so standard PDF Helvetica fonts render without warnings.
  static String sanitizePdfText(String input) {
    final normalized = input
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('·', '|')
        .replaceAll('•', '|');
    final buf = StringBuffer();
    for (final codeUnit in normalized.codeUnits) {
      if (codeUnit >= 0x20 && codeUnit <= 0x7E) {
        buf.writeCharCode(codeUnit);
      }
    }
    final collapsed = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.isEmpty ? '-' : collapsed;
  }

  static Future<Uint8List> generatePeriodReport({
    required AppDatabase db,
    required String accountDisplayName,
    required String periodLabel,
  }) async {
    final txs = await db.getActiveTransactions(yearMonth: periodLabel);
    final debts = await db.getActiveDebts();
    final plans = await db.getActiveInstallmentPlans();
    final categories = await db.getActiveCategories();
    final budgets = await db.getActiveBudgets(periodMonth: periodLabel);

    final categoryNames = <String, String>{
      for (final c in categories) c.id: sanitizePdfText(c.name),
    };
    final budgetMap = <String, LocalBudget>{
      for (final b in budgets) b.categoryId: b,
    };

    var totalIncome = 0;
    var totalExpense = 0;
    final expenseByCategory = <String, int>{};

    for (final tx in txs) {
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
        final catKey = tx.categoryId ?? '_uncategorized';
        expenseByCategory[catKey] = (expenseByCategory[catKey] ?? 0) + tx.amount;
      }
    }

    final netBalance = totalIncome - totalExpense;
    final totalActiveDebt = debts
        .where((d) => d.direction == 'payable')
        .fold<int>(0, (sum, d) => sum + d.remainingAmount);
    final totalActiveReceivable = debts
        .where((d) => d.direction == 'receivable')
        .fold<int>(0, (sum, d) => sum + d.remainingAmount);
    var totalInstallmentRemaining = 0;
    for (final p in plans) {
      final terms = await db.getInstallmentsForPlan(p.id);
      for (final t in terms) {
        totalInstallmentRemaining += t.remainingAmount;
      }
    }

    final allCategoryIds = <String>{
      ...expenseByCategory.keys,
      ...budgetMap.keys,
    }.toList();

    final categoryRows = allCategoryIds.map((catId) {
      final catName = categoryNames[catId] ?? 'Lainnya';
      final spent = expenseByCategory[catId] ?? 0;
      final budget = budgetMap[catId];
      if (budget == null) {
        return [
          catName,
          RupiahFormatter.format(spent),
          '-',
          'Tanpa Batas',
        ];
      }
      final ratioPct = budget.limitAmount > 0
          ? ((spent * 100) / budget.limitAmount).round()
          : 0;
      final status = spent > budget.limitAmount
          ? 'Melebihi ($ratioPct%)'
          : ratioPct >= 80
              ? 'Waspada ($ratioPct%)'
              : 'Aman ($ratioPct%)';
      return [
        catName,
        RupiahFormatter.format(spent),
        RupiahFormatter.format(budget.limitAmount),
        status,
      ];
    }).toList();

    final safeAccountName = sanitizePdfText(accountDisplayName);
    final safePeriod = sanitizePdfText(periodLabel);

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'LAPORAN BUKU KAS PRIBADI',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Akun: $safeAccountName | Periode: $safePeriod',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.Text(
                'Dicetak: ${DateTime.now().toIso8601String().substring(0, 10)}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 1),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Pemasukan', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(
                          RupiahFormatter.format(totalIncome),
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Pengeluaran', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(
                          RupiahFormatter.format(totalExpense),
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Saldo Bersih', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(
                          RupiahFormatter.format(netBalance),
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColors.grey300, height: 1),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Sisa Hutang Aktif',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          RupiahFormatter.format(totalActiveDebt),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Piutang Aktif',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          RupiahFormatter.format(totalActiveReceivable),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Sisa Cicilan (${plans.length} Rencana)',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          RupiahFormatter.format(totalInstallmentRemaining),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (categoryRows.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Ringkasan Pengeluaran per Kategori & Anggaran',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Kategori',
                'Realisasi',
                'Batas Anggaran',
                'Status',
              ],
              data: categoryRows,
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Text(
            'Rincian Transaksi (${txs.length} Entri)',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Tanggal', 'Tipe', 'Kategori', 'Judul', 'Nominal'],
            data: txs
                .map(
                  (t) => [
                    sanitizePdfText(t.transactionDate),
                    t.type == 'income' ? 'Pemasukan' : 'Pengeluaran',
                    categoryNames[t.categoryId ?? ''] ?? 'Umum',
                    sanitizePdfText(t.title ?? 'Transaksi'),
                    RupiahFormatter.format(t.amount),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );

    return doc.save();
  }
}
