import 'dart:convert';
import 'dart:typed_data';

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

class ReportsAndMoreScreen extends ConsumerStatefulWidget {
  const ReportsAndMoreScreen({super.key});

  @override
  ConsumerState<ReportsAndMoreScreen> createState() =>
      _ReportsAndMoreScreenState();
}

class _ReportsAndMoreScreenState extends ConsumerState<ReportsAndMoreScreen> {
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

  Future<void> _exportBackupJson(
    BuildContext context,
    AppDatabase db,
    String accountName,
  ) async {
    final jsonStr = await BackupExportService.generateBackupJsonString(db);
    if (!context.mounted) return;
    await Printing.sharePdf(
      bytes: Uint8List.fromList(utf8.encode(jsonStr)),
      filename: 'Cadangan_Kas_$accountName.json',
    );
  }

  Future<void> _showRestoreBackupDialog(
    BuildContext context,
    AppDatabase db,
  ) async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan Cadangan JSON'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Tempel isi file JSON cadangan di sini...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await BackupExportService.restoreFromJsonString(
                  db,
                  ctrl.text.trim(),
                );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data cadangan JSON berhasil dipulihkan.'),
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: SwissLedgerColors.dangerRed,
                      content: Text('Gagal memulihkan JSON: $e'),
                    ),
                  );
                }
              }
            },
            child: const Text('Pulihkan Sekarang'),
          ),
        ],
      ),
    );
  }

  Future<void> _showManageCategoriesSheet(
    BuildContext context,
    AppDatabase db,
  ) async {
    final txRepo = ref.read(transactionRepositoryProvider);
    if (txRepo == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SwissLedgerColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        var newKind = 'expense';
        final nameCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return FutureBuilder<List<LocalCategory>>(
              future: db.getActiveCategories(),
              builder: (ctx, snap) {
                final cats = snap.data ?? const <LocalCategory>[];
                return Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Kelola Kategori Transaksi',
                          style: SwissLedgerTypography.sans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Pengeluaran'),
                              selected: newKind == 'expense',
                              onSelected: (_) =>
                                  setSheetState(() => newKind = 'expense'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Pemasukan'),
                              selected: newKind == 'income',
                              onSelected: (_) =>
                                  setSheetState(() => newKind = 'income'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('new_category_name_field'),
                                controller: nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Nama Kategori Baru',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              key: const Key('add_category_submit_button'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SwissLedgerColors.accentTeal,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                final text = nameCtrl.text.trim();
                                if (text.isEmpty) return;
                                await txRepo.createCustomCategory(
                                  name: text,
                                  kind: newKind,
                                );
                                nameCtrl.clear();
                                setSheetState(() {});
                                if (mounted) setState(() {});
                              },
                              child: const Text('Tambah'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: cats.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: SwissLedgerColors.borderHairline,
                            ),
                            itemBuilder: (_, idx) {
                              final c = cats[idx];
                              final isDefault = c.isSystem;
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  c.name,
                                  style: SwissLedgerTypography.sans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${c.kind == 'income' ? 'Pemasukan' : 'Pengeluaran'}${isDefault ? ' · Bawaan' : ' · Kustom'}',
                                  style: SwissLedgerTypography.sans(
                                    fontSize: 11,
                                    color: SwissLedgerColors.textMuted,
                                  ),
                                ),
                                trailing: isDefault
                                    ? null
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Ubah Nama',
                                            icon: const Icon(
                                              PhosphorIconsRegular.pencilSimple,
                                              size: 16,
                                            ),
                                            onPressed: () async {
                                              final renameCtrl =
                                                  TextEditingController(
                                                text: c.name,
                                              );
                                              final newName =
                                                  await showDialog<String>(
                                                context: ctx,
                                                builder: (dCtx) => AlertDialog(
                                                  title: const Text(
                                                    'Ubah Nama Kategori',
                                                  ),
                                                  content: TextField(
                                                    controller: renameCtrl,
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText: 'Nama Kategori',
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(dCtx)
                                                              .pop(),
                                                      child:
                                                          const Text('Batal'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.of(dCtx)
                                                              .pop(
                                                        renameCtrl.text.trim(),
                                                      ),
                                                      child:
                                                          const Text('Simpan'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (newName != null &&
                                                  newName.isNotEmpty) {
                                                await txRepo.updateCategory(
                                                  categoryId: c.id,
                                                  name: newName,
                                                );
                                                setSheetState(() {});
                                                if (mounted) setState(() {});
                                              }
                                            },
                                          ),
                                          IconButton(
                                            tooltip: 'Arsipkan',
                                            icon: const Icon(
                                              PhosphorIconsRegular.trash,
                                              size: 16,
                                              color:
                                                  SwissLedgerColors.dangerRed,
                                            ),
                                            onPressed: () async {
                                              await txRepo.archiveCategory(
                                                c.id,
                                              );
                                              setSheetState(() {});
                                              if (mounted) setState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showManageProfileDialog(BuildContext context) async {
    final authRepo = ref.read(authRepositoryProvider);
    final session = authRepo.currentSession;
    final nameCtrl = TextEditingController(text: session?.displayName ?? '');
    final currPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Pengaturan Profil & Kata Sandi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (errorMsg != null) ...[
                  Text(
                    errorMsg!,
                    style: SwissLedgerTypography.sans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SwissLedgerColors.dangerRed,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  key: const Key('profile_display_name_field'),
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Tampilan',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('profile_current_password_field'),
                  controller: currPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kata Sandi Saat Ini (Opsional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('profile_new_password_field'),
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kata Sandi Baru (Opsional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              key: const Key('profile_save_submit_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SwissLedgerColors.accentTeal,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                if (newName.isEmpty) {
                  setDialogState(() {
                    errorMsg = 'Nama tampilan tidak boleh kosong.';
                  });
                  return;
                }
                try {
                  await authRepo.updateProfile(
                    displayName: newName,
                    currentPassword: currPassCtrl.text.trim().isEmpty
                        ? null
                        : currPassCtrl.text.trim(),
                    newPassword: newPassCtrl.text.trim().isEmpty
                        ? null
                        : newPassCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) setState(() {});
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profil akun berhasil diperbarui.'),
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() {
                    errorMsg = 'Gagal memperbarui profil: $e';
                  });
                }
              },
              child: const Text('Simpan Profil'),
            ),
          ],
        ),
      ),
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

  String _formatConflictEntityLabel(String entityType) {
    switch (entityType) {
      case 'transactions':
        return 'Transaksi';
      case 'debts':
        return 'Hutang / Piutang';
      case 'installment_plans':
        return 'Rencana Cicilan';
      case 'installments':
        return 'Termin Cicilan';
      case 'wishlist':
        return 'Wishlist';
      case 'categories':
        return 'Kategori';
      case 'budgets':
        return 'Anggaran Kategori';
      default:
        return entityType;
    }
  }

  String _describePayload(Map<String, dynamic> decoded) {
    final title = (decoded['title'] ??
            decoded['item_name'] ??
            decoded['counterparty_name'] ??
            decoded['name'] ??
            decoded['period_month'] ??
            '')
        .toString()
        .trim();
    final rawAmount = decoded['amount'] ??
        decoded['remaining_amount'] ??
        decoded['saved_amount'] ??
        decoded['target_amount'] ??
        decoded['principal_amount'] ??
        decoded['total_amount'] ??
        decoded['limit_amount'];
    final amountInt = rawAmount is num
        ? rawAmount.toInt()
        : int.tryParse(rawAmount?.toString() ?? '');

    if (title.isNotEmpty && amountInt != null) {
      return '$title · ${RupiahFormatter.format(amountInt)}';
    } else if (title.isNotEmpty) {
      return title;
    } else if (amountInt != null) {
      return RupiahFormatter.format(amountInt);
    }
    return 'Data Pembaruan';
  }

  Widget _buildReminderGroup({
    required String label,
    required Color accentColor,
    required List<_DueReminderItem> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$label (${items.length})',
              style: SwissLedgerTypography.sans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.title} (${item.dueDate ?? '-'})',
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
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(activeDatabaseProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final session = authRepo.currentSession;

    if (db == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<_ReportScreenData>(
      future: _loadReportData(db, selectedMonth),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final formattedPeriod = RupiahFormatter.formatMonthYear(selectedMonth);
        final overdueItems = data.reminders
            .where((r) => r.status == ObligationStatus.overdue)
            .toList();
        final dueTodayItems = data.reminders
            .where((r) => r.status == ObligationStatus.dueToday)
            .toList();
        final upcomingItems = data.reminders
            .where((r) => r.status == ObligationStatus.upcoming)
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            // Analytics Card (Category & Payment Method Breakdown)
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
                  Row(
                    children: [
                      const Icon(
                        PhosphorIconsRegular.chartPieSlice,
                        size: 15,
                        color: SwissLedgerColors.accentTeal,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'ANALITIK PENGELUARAN & METODE PEMBAYARAN ($formattedPeriod)',
                          style: SwissLedgerTypography.sans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: SwissLedgerColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (data.categoryStats.isEmpty)
                    Text(
                      'Belum ada pengeluaran di bulan $formattedPeriod.',
                      style: SwissLedgerTypography.sans(
                        fontSize: 12,
                        color: SwissLedgerColors.textMuted,
                      ),
                    )
                  else ...[
                    Text(
                      'Proporsi per Kategori',
                      style: SwissLedgerTypography.sans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SwissLedgerColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final stat in data.categoryStats)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${stat.label} (${stat.percent}%)',
                                    style: SwissLedgerTypography.sans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  RupiahFormatter.format(stat.amount),
                                  style: SwissLedgerTypography.monoTabular(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (stat.percent / 100.0).clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: SwissLedgerColors.surfaceSubtle,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  SwissLedgerColors.accentTeal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Divider(
                      height: 1,
                      color: SwissLedgerColors.borderHairline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Distribusi Metode Pembayaran',
                      style: SwissLedgerTypography.sans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SwissLedgerColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final pm in data.paymentMethodStats)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: SwissLedgerColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: SwissLedgerColors.borderHairline,
                              ),
                            ),
                            child: Text(
                              '${pm.label}: ${RupiahFormatter.format(pm.amount)} (${pm.percent}%)',
                              style: SwissLedgerTypography.sans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),
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
                      session?.displayName ?? 'Pengguna',
                      selectedMonth,
                    ),
                    icon: const Icon(PhosphorIconsRegular.filePdf, size: 16),
                    label: Text(
                      'Unduh Laporan PDF ($formattedPeriod)',
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
                    onPressed: () => _exportBackupJson(
                      context,
                      db,
                      session?.displayName ?? 'Pengguna',
                    ),
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
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('restore_backup_json_button'),
                    onPressed: () => _showRestoreBackupDialog(context, db),
                    icon: const Icon(
                      PhosphorIconsRegular.arrowsClockwise,
                      size: 16,
                    ),
                    label: Text(
                      'Pulihkan Cadangan Data (JSON)',
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
            // Due Reminders Section (Grouped into Overdue, Due Today, Upcoming)
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
                  else ...[
                    _buildReminderGroup(
                      label: 'Terlambat',
                      accentColor: SwissLedgerColors.dangerRed,
                      items: overdueItems,
                    ),
                    _buildReminderGroup(
                      label: 'Jatuh Tempo Hari Ini',
                      accentColor: SwissLedgerColors.warningAmber,
                      items: dueTodayItems,
                    ),
                    _buildReminderGroup(
                      label: 'Mendatang',
                      accentColor: SwissLedgerColors.accentTeal,
                      items: upcomingItems,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),
            // Category & Account Settings Card
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
                    'PENGATURAN KATEGORI & PROFIL AKUN',
                    style: SwissLedgerTypography.sans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SwissLedgerColors.textMuted,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('manage_categories_button'),
                    onPressed: () => _showManageCategoriesSheet(context, db),
                    icon: const Icon(PhosphorIconsRegular.tag, size: 16),
                    label: Text(
                      'Kelola Kategori Transaksi',
                      style: SwissLedgerTypography.sans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('manage_profile_button'),
                    onPressed: () => _showManageProfileDialog(context),
                    icon: const Icon(PhosphorIconsRegular.lockKey, size: 16),
                    label: Text(
                      'Pengaturan Profil & Kata Sandi',
                      style: SwissLedgerTypography.sans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
                    const SizedBox(height: 10),
                    for (final c in data.conflicts)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SwissLedgerColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: SwissLedgerColors.borderHairline,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatConflictEntityLabel(c.entityType),
                              style: SwissLedgerTypography.sans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: SwissLedgerColors.warningAmber,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Versi Perangkat: ${_describePayload(c.localPayload)}',
                              style: SwissLedgerTypography.sans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: SwissLedgerColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Versi Server: ${_describePayload(c.serverPayload)}',
                              style: SwissLedgerTypography.sans(
                                fontSize: 12,
                                color: SwissLedgerColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () async {
                                    final syncEngine =
                                        ref.read(syncEngineProvider);
                                    if (syncEngine != null) {
                                      await syncEngine
                                          .resolveConflictUseLocal(c.id);
                                      if (mounted) setState(() {});
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Gunakan Lokal'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    final syncEngine =
                                        ref.read(syncEngineProvider);
                                    if (syncEngine != null) {
                                      await syncEngine
                                          .resolveConflictUseServer(c.id);
                                      if (mounted) setState(() {});
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Gunakan Server'),
                                ),
                              ],
                            ),
                          ],
                        ),
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
                'Keluar dari Akun (${session?.displayName ?? 'Pengguna'})',
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

  String _extractPaymentMethod(LocalTransaction tx) {
    final source = '${tx.notes ?? ''} ${tx.title ?? ''}'.toLowerCase();
    if (source.contains('qris') || source.contains('e-wallet')) {
      return 'QRIS / E-Wallet';
    }
    if (source.contains('transfer')) {
      return 'Transfer Bank';
    }
    if (source.contains('tunai')) {
      return 'Tunai';
    }
    return 'Lainnya / Manual';
  }

  Future<_ReportScreenData> _loadReportData(
    AppDatabase db,
    String selectedMonth,
  ) async {
    final debts = await db.getActiveDebts();
    final plans = await db.getActiveInstallmentPlans();
    final conflicts = await db.getSyncConflicts();
    final txs = await db.getActiveTransactions(yearMonth: selectedMonth);
    final categories = await db.getActiveCategories();
    final reminders = <_DueReminderItem>[];

    final categoryNames = <String, String>{
      for (final c in categories) c.id: c.name,
    };

    var totalExpense = 0;
    final expenseByCategory = <String, int>{};
    final expenseByPaymentMethod = <String, int>{};

    for (final tx in txs) {
      if (tx.type == 'expense') {
        totalExpense += tx.amount;
        final catName = categoryNames[tx.categoryId ?? ''] ?? 'Pengeluaran Umum';
        expenseByCategory[catName] =
            (expenseByCategory[catName] ?? 0) + tx.amount;
        final pm = _extractPaymentMethod(tx);
        expenseByPaymentMethod[pm] =
            (expenseByPaymentMethod[pm] ?? 0) + tx.amount;
      }
    }

    final categoryStats = expenseByCategory.entries
        .map(
          (e) => _BreakdownStat(
            label: e.key,
            amount: e.value,
            percent: totalExpense > 0
                ? ((e.value * 100) / totalExpense).round()
                : 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final paymentMethodStats = expenseByPaymentMethod.entries
        .map(
          (e) => _BreakdownStat(
            label: e.key,
            amount: e.value,
            percent: totalExpense > 0
                ? ((e.value * 100) / totalExpense).round()
                : 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    for (final d in debts.where((d) => d.remainingAmount > 0)) {
      reminders.add(
        _DueReminderItem(
          title: d.counterpartyName,
          amount: d.remainingAmount,
          dueDate: d.dueDate,
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
            dueDate: nextUnpaid.dueDate,
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
      categoryStats: categoryStats,
      paymentMethodStats: paymentMethodStats,
    );
  }
}

class _BreakdownStat {
  final String label;
  final int amount;
  final int percent;

  const _BreakdownStat({
    required this.label,
    required this.amount,
    required this.percent,
  });
}

class _DueReminderItem {
  final String title;
  final int amount;
  final String? dueDate;
  final ObligationStatus status;

  const _DueReminderItem({
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.status,
  });
}

class _ReportScreenData {
  final List<_DueReminderItem> reminders;
  final List<SyncConflictEntry> conflicts;
  final List<_BreakdownStat> categoryStats;
  final List<_BreakdownStat> paymentMethodStats;

  const _ReportScreenData({
    required this.reminders,
    required this.conflicts,
    required this.categoryStats,
    required this.paymentMethodStats,
  });
}
