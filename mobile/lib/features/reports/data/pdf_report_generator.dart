import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/money/rupiah_formatter.dart';

class PdfReportGenerator {
  const PdfReportGenerator._();

  static Future<Uint8List> generatePeriodReport({
    required AppDatabase db,
    required String accountDisplayName,
    required String periodLabel,
  }) async {
    final txs = await db.getActiveTransactions(yearMonth: periodLabel);
    final debts = await db.getActiveDebts();
    final plans = await db.getActiveInstallmentPlans();

    var totalIncome = 0;
    var totalExpense = 0;
    for (final tx in txs) {
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }
    }
    final netBalance = totalIncome - totalExpense;
    final totalActiveDebt = debts
        .where((d) => d.direction == 'payable')
        .fold<int>(0, (sum, d) => sum + d.remainingAmount);

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
                    'Akun: $accountDisplayName | Periode: $periodLabel',
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
            child: pw.Row(
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
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Sisa Hutang Aktif (${plans.length} Rencana Cicilan)',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      RupiahFormatter.format(totalActiveDebt),
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Rincian Transaksi (${txs.length} Entri)',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Tanggal', 'Tipe', 'Judul', 'Nominal'],
            data: txs
                .map(
                  (t) => [
                    t.transactionDate,
                    t.type == 'income' ? 'Pemasukan' : 'Pengeluaran',
                    t.title ?? 'Transaksi',
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
