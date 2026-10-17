import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/providers/app_providers.dart';
import 'package:personal_finance/app/theme/swiss_ledger_theme.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/finance/obligation_status.dart';
import 'package:personal_finance/core/money/rupiah_formatter.dart';
import 'package:personal_finance/features/reports/data/backup_export_service.dart';
import 'package:personal_finance/features/reports/data/pdf_report_generator.dart';
import 'package:printing/printing.dart';

class ReportsAndMoreScreen extends ConsumerWidget {
  const ReportsAndMoreScreen({super.key});

  Future<void> _exportPdf(
    BuildContext context,
    AppDatabase db,
    String accountName,
    String periodLabel,
  ) async {
    final bytes = await PdfReportGenerator.generatePeriodReport(
      db: db,
      accountDisplayName: accountName,
      periodLabel: periodLabel,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Laporan_Kas_${accountName}_$periodLabel.pdf',
    );
  }

  Future<void> _handleSafeLogout(BuildContext context, WidgetRef ref) async {
    final authRepo = ref.read(authRepositoryProvider);
    final safety = await authRepo.checkLogoutSafety();
    if (!context.mounted) return;

    if (!safety.hasPendingOperations) {
      await authRepo.logout(forceDiscardPending: false, deleteLocalCache: false);
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Perubahan Belum Tersinkronisasi'),
        content: Text(
          'Terdapat ${safety.pendingCount} entri di antrean lokal yang belum dikirim ke server. Pilih tindakan sebelum keluar:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Batal'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop('keep_cache'),
            child: const Text('Tetap Simpan Cache & Keluar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SwissLedgerColors.accentTeal,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop('sync_now'),
            child: const Text('Sinkronkan Sekarang'),
          ),
        ],
      ),
    );

    if (choice == 'sync_now') {
      final syncEngine = ref.read(syncEngineProvider);
      if (syncEngine != null) {
        final res = await syncEngine.synchronize();
        if (res.success) {
          await authRepo.logout(
            forceDiscardPending: false,
            deleteLocalCache: false,
          );
        }
      }
    } else if (choice == 'keep_cache') {
      await authRepo.logout(
        forceDiscardPending: true,
        deleteLocalCache: false,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(activeDatabaseProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final session = authRepo.currentSession;

    if (db == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<_ReportScreenData>(
      future: _loadReportData(db),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            // PDF & Backup Action Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SwissLedgerColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SwissLedgerColors.borderHairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'LAPORAN & CADANGAN LOKAL',
                    style: SwissLedgerTypography.sans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SwissLedgerColors.textMuted,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cetak laporan PDF bulanan langsung dari penyimpanan lokal perangkat tanpa membutuhkan koneksi internet.',
                    style: SwissLedgerTypography.sans(
                      fontSize: 12,
                      color: SwissLedgerColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    key: const Key('export_pdf_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SwissLedgerColors.accentTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _exportPdf(
                      context,
                      db,
                      session?.displayName ?? 'Anzhel',
                      selectedMonth,
                    ),
                    icon: const Icon(PhosphorIconsRegular.filePdf, size: 16),
                    label: Text(
                      'Unduh Laporan PDF ($selectedMonth)',
                      style: SwissLedgerTypography.sans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('export_backup_json_button'),
                    onPressed: () async {
                      final jsonStr =
                          await BackupExportService.generateBackupJsonString(db);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Snapshot JSON siap (${jsonStr.length} byte)',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      PhosphorIconsRegular.downloadSimple,
                      size: 16,
                    ),
                    label: Text(
                      'Ekspor Cadangan Data (JSON)',
                      style: SwissLedgerTypography.sans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            // Due Reminders Section (Debts + Installment Terms)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SwissLedgerColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SwissLedgerColors.borderHairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PENGINGAT JATUH TEMPO (HUTANG & CICILAN)',
                    style: SwissLedgerTypography.sans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SwissLedgerColors.textMuted,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (data.reminders.isEmpty)
                    Text(
                      'Tidak ada kewajiban yang mendekati jatuh tempo.',
                      style: SwissLedgerTypography.sans(
                        fontSize: 12,
                        color: SwissLedgerColors.textMuted,
                      ),
                    )
                  else
                    for (final item in data.reminders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.title} (${item.status.label})',
                                style: SwissLedgerTypography.sans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              RupiahFormatter.format(item.amount),
                              style: SwissLedgerTypography.monoTabular(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: SwissLedgerColors.warningAmber,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),

            if (data.conflicts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SwissLedgerColors.warningSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SwissLedgerColors.warningAmber),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terdapat ${data.conflicts.length} konflik sinkronisasi.',
                      style: SwissLedgerTypography.sans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SwissLedgerColors.warningAmber,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final c in data.conflicts)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${c.entityType} (${c.entityId.substring(0, 8)})',
                              style: SwissLedgerTypography.monoTabular(
                                fontSize: 11,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              db.execute(
                                'DELETE FROM sync_conflicts WHERE id = ?',
                                [c.id],
                              );
                              db.notifyDataChanged();
                            },
                            child: const Text('Gunakan Server'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('safe_logout_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: SwissLedgerColors.dangerRed,
                side: const BorderSide(color: SwissLedgerColors.borderHairline),
              ),
              onPressed: () => _handleSafeLogout(context, ref),
              icon: const Icon(PhosphorIconsRegular.signOut, size: 16),
              label: Text(
                'Keluar dari Akun (${session?.displayName ?? 'Anzhel'})',
                style: SwissLedgerTypography.sans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SwissLedgerColors.dangerRed,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<_ReportScreenData> _loadReportData(AppDatabase db) async {
    final debts = await db.getActiveDebts();
    final plans = await db.getActiveInstallmentPlans();
    final conflicts = await db.getSyncConflicts();
    final reminders = <_DueReminderItem>[];

    for (final d in debts.where((d) => d.remainingAmount > 0)) {
      reminders.add(
        _DueReminderItem(
          title: d.counterpartyName,
          amount: d.remainingAmount,
          status: ObligationStatusCalculator.deriveFromIso(
            remainingAmount: d.remainingAmount,
            dueDateIso: d.dueDate,
          ),
        ),
      );
    }

    for (final p in plans) {
      final terms = await db.getInstallmentsForPlan(p.id);
      final nextUnpaid = terms.where((t) => t.remainingAmount > 0).firstOrNull;
      if (nextUnpaid != null) {
        reminders.add(
          _DueReminderItem(
            title: '${p.title} #${nextUnpaid.installmentNumber}',
            amount: nextUnpaid.remainingAmount,
            status: ObligationStatusCalculator.deriveFromIso(
              remainingAmount: nextUnpaid.remainingAmount,
              dueDateIso: nextUnpaid.dueDate,
            ),
          ),
        );
      }
    }

    return _ReportScreenData(
      reminders: reminders,
      conflicts: conflicts,
    );
  }
}

class _DueReminderItem {
  final String title;
  final int amount;
  final ObligationStatus status;

  const _DueReminderItem({
    required this.title,
    required this.amount,
    required this.status,
  });
}

class _ReportScreenData {
  final List<_DueReminderItem> reminders;
  final List<SyncConflictEntry> conflicts;

  const _ReportScreenData({
    required this.reminders,
    required this.conflicts,
  });
}
