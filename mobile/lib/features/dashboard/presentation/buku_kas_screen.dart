import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/providers/app_providers.dart';
import 'package:personal_finance/app/theme/swiss_ledger_theme.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/money/rupiah_formatter.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add_transaction_sheet.dart';

class BukuKasScreen extends ConsumerWidget {
  const BukuKasScreen({super.key});

  String _shiftMonth(String currentYearMonth, int deltaMonths) {
    final parts = currentYearMonth.split('-');
    final year = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 2026) : 2026;
    final month = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;
    final shifted = DateTime(year, month + deltaMonths, 1);
    return '${shifted.year.toString().padLeft(4, '0')}-${shifted.month.toString().padLeft(2, '0')}';
  }

  Future<void> _showEditTransactionDialog(
    BuildContext context,
    WidgetRef ref,
    LocalTransaction tx,
  ) async {
    final titleCtrl = TextEditingController(text: tx.title ?? '');
    final amountCtrl = TextEditingController(
      text: RupiahFormatter.formatNumberOnly(tx.amount),
    );
    final dateCtrl = TextEditingController(text: tx.transactionDate);
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Ubah Transaksi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('edit_tx_title_input'),
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Catatan / Judul',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('edit_tx_amount_input'),
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [RupiahInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Nominal (Rp)',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('edit_tx_date_input'),
                  controller: dateCtrl,
                  readOnly: false,
                  decoration: InputDecoration(
                    labelText: 'Tanggal Transaksi',
                    suffixIcon: IconButton(
                      icon: const Icon(
                        PhosphorIconsRegular.calendarBlank,
                        size: 16,
                      ),
                      onPressed: () async {
                        final initial =
                            DateTime.tryParse(dateCtrl.text.trim()) ??
                            DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: initial,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setModalState(() {
                            dateCtrl.text = picked
                                .toIso8601String()
                                .substring(0, 10);
                          });
                        }
                      },
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: SwissLedgerTypography.sans(
                      fontSize: 12,
                      color: SwissLedgerColors.dangerRed,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              key: const Key('save_edit_tx_button'),
              onPressed: () async {
                final repo = ref.read(transactionRepositoryProvider);
                final amount = RupiahFormatter.parseDigits(amountCtrl.text);
                final dateText = dateCtrl.text.trim();
                if (repo == null || amount <= 0 || dateText.isEmpty) {
                  setModalState(() {
                    errorText =
                        'Nominal harus lebih dari Rp 0 dan tanggal wajib diisi.';
                  });
                  return;
                }
                await repo.updateTransaction(
                  transactionId: tx.id,
                  amount: amount,
                  transactionDate: dateText,
                  title: titleCtrl.text.trim().isEmpty
                      ? null
                      : titleCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndReverseTransaction(
    BuildContext context,
    WidgetRef ref,
    LocalTransaction tx,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Koreksi Transaksi'),
        content: Text(
          'Batalkan "${tx.title ?? 'Transaksi'}" sebesar ${RupiahFormatter.format(tx.amount)}? Sistem akan mencatat entri jurnal pembalik secara otomatis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            key: const Key('confirm_reverse_tx_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SwissLedgerColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Koreksi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(transactionRepositoryProvider);
    if (repo == null) return;
    await repo.reverseTransaction(
      originalTransactionId: tx.id,
      reversalDate: tx.transactionDate,
      notes: 'Koreksi dari Buku Kas',
    );
  }

  Future<void> _showTransactionActionSheet(
    BuildContext context,
    WidgetRef ref,
    LocalTransaction tx,
    LocalCategory? category,
  ) async {
    final isIncome = tx.type == 'income';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: SwissLedgerColors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(
            top: BorderSide(color: SwissLedgerColors.borderHairline, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SwissLedgerColors.borderHairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tx.title ?? category?.name ?? 'Transaksi',
                style: SwissLedgerTypography.sans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${category?.name ?? 'Umum'} · ${RupiahFormatter.formatIsoDate(tx.transactionDate)}',
                style: SwissLedgerTypography.sans(
                  fontSize: 12,
                  color: SwissLedgerColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isIncome
                    ? '+${RupiahFormatter.format(tx.amount)}'
                    : '-${RupiahFormatter.format(tx.amount)}',
                style: SwissLedgerTypography.monoTabular(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isIncome
                      ? SwissLedgerColors.accentTeal
                      : SwissLedgerColors.dangerRed,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (tx.sourceType == 'manual') ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showEditTransactionDialog(context, ref, tx);
                        },
                        icon: const Icon(
                          PhosphorIconsRegular.pencilSimple,
                          size: 16,
                        ),
                        label: const Text('Ubah Transaksi'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SwissLedgerColors.dangerRed,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _confirmAndReverseTransaction(context, ref, tx);
                      },
                      icon: const Icon(
                        PhosphorIconsRegular.arrowsClockwise,
                        size: 16,
                      ),
                      label: const Text('Koreksi Jurnal'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(activeDatabaseProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final selectedCatId = ref.watch(selectedCategoryFilterProvider);

    if (db == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<_BukuKasViewData>(
      future: _loadData(db, selectedMonth),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredTxs = data.transactions.where((tx) {
          if (selectedCatId != null && tx.categoryId != selectedCatId) {
            return false;
          }
          if (searchQuery.trim().isNotEmpty) {
            final q = searchQuery.trim().toLowerCase();
            final titleMatch = (tx.title ?? '').toLowerCase().contains(q);
            final notesMatch = (tx.notes ?? '').toLowerCase().contains(q);
            return titleMatch || notesMatch;
          }
          return true;
        }).toList();

        final categoryList = data.categoriesById.values.toList();
        final totalActiveDebtAmount = data.activeDebts.fold<int>(
          0,
          (sum, d) => sum + d.remainingAmount,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            // Monthly Ledger Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SwissLedgerColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SwissLedgerColors.borderHairline,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'SALDO BERSIH BULAN INI',
                          overflow: TextOverflow.ellipsis,
                          style: SwissLedgerTypography.sans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: SwissLedgerColors.textMuted,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            key: const Key('buku_kas_prev_month_button'),
                            onTap: () {
                              ref.read(selectedMonthProvider.notifier).state =
                                  _shiftMonth(selectedMonth, -1);
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Icon(
                                Icons.chevron_left,
                                size: 18,
                                color: SwissLedgerColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            RupiahFormatter.formatMonthYear(selectedMonth),
                            style: SwissLedgerTypography.sans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: SwissLedgerColors.textPrimary,
                            ),
                          ),
                          InkWell(
                            key: const Key('buku_kas_next_month_button'),
                            onTap: () {
                              ref.read(selectedMonthProvider.notifier).state =
                                  _shiftMonth(selectedMonth, 1);
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: SwissLedgerColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    RupiahFormatter.format(data.netBalance),
                    key: const Key('buku_kas_net_balance'),
                    style: SwissLedgerTypography.monoTabular(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: SwissLedgerColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: SwissLedgerColors.borderHairline),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PEMASUKAN',
                              style: SwissLedgerTypography.sans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: SwissLedgerColors.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '+${RupiahFormatter.format(data.totalIncome)}',
                              style: SwissLedgerTypography.monoTabular(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: SwissLedgerColors.accentTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PENGELUARAN',
                              style: SwissLedgerTypography.sans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: SwissLedgerColors.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '-${RupiahFormatter.format(data.totalExpense)}',
                              style: SwissLedgerTypography.monoTabular(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: SwissLedgerColors.dangerRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (data.activeDebts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: SwissLedgerColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: SwissLedgerColors.borderHairline,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.activeDebts.length == 1
                                ? 'KEWAJIBAN AKTIF (${data.activeDebts.first.counterpartyName})'
                                : '${data.activeDebts.length} KEWAJIBAN AKTIF (${data.activeDebts.first.counterpartyName}, dll.)',
                            style: SwissLedgerTypography.sans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: SwissLedgerColors.warningAmber,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.activeDebts.length == 1
                                ? (data.activeDebts.first.title ?? 'Hutang / Piutang')
                                : 'Total sisa kewajiban aktif berjalan',
                            style: SwissLedgerTypography.sans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      RupiahFormatter.format(totalActiveDebtAmount),
                      style: SwissLedgerTypography.monoTabular(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SwissLedgerColors.warningAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            // Search field
            TextField(
              onChanged: (val) =>
                  ref.read(searchQueryProvider.notifier).state = val,
              style: SwissLedgerTypography.sans(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cari judul atau catatan transaksi...',
                prefixIcon: const Icon(
                  PhosphorIconsRegular.magnifyingGlass,
                  size: 16,
                  color: SwissLedgerColors.textMuted,
                ),
                suffixIcon: searchQuery.trim().isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          PhosphorIconsRegular.xCircle,
                          size: 16,
                          color: SwissLedgerColors.textMuted,
                        ),
                        onPressed: () =>
                            ref.read(searchQueryProvider.notifier).state = '',
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: SwissLedgerColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: SwissLedgerColors.borderHairline,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: SwissLedgerColors.borderHairline,
                  ),
                ),
              ),
            ),

            if (categoryList.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CategoryFilterChip(
                      label: 'Semua Kategori',
                      selected: selectedCatId == null,
                      onTap: () => ref
                          .read(selectedCategoryFilterProvider.notifier)
                          .state = null,
                    ),
                    for (final c in categoryList) ...[
                      const SizedBox(width: 6),
                      _CategoryFilterChip(
                        label: c.name,
                        selected: selectedCatId == c.id,
                        onTap: () => ref
                            .read(selectedCategoryFilterProvider.notifier)
                            .state = selectedCatId == c.id ? null : c.id,
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'JURNAL TRANSAKSI',
                  style: SwissLedgerTypography.sans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SwissLedgerColors.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  '${filteredTxs.length} entri',
                  style: SwissLedgerTypography.monoTabular(
                    fontSize: 11,
                    color: SwissLedgerColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: SwissLedgerColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SwissLedgerColors.borderHairline,
                  width: 1,
                ),
              ),
              child: filteredTxs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 28,
                        horizontal: 16,
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.receipt,
                            size: 24,
                            color: SwissLedgerColors.textMuted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada transaksi tercatat pada periode ini.',
                            textAlign: TextAlign.center,
                            style: SwissLedgerTypography.sans(
                              fontSize: 13,
                              color: SwissLedgerColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              showModalBottomSheet<bool>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) =>
                                    const QuickAddTransactionSheet(),
                              );
                            },
                            icon: const Icon(
                              PhosphorIconsRegular.plus,
                              size: 14,
                            ),
                            label: Text(
                              'Catat Transaksi Pertama',
                              style: SwissLedgerTypography.sans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < filteredTxs.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              color: SwissLedgerColors.borderHairline,
                            ),
                          _LedgerTransactionRow(
                            tx: filteredTxs[i],
                            onTapRow: () => _showTransactionActionSheet(
                              context,
                              ref,
                              filteredTxs[i],
                              data.categoriesById[filteredTxs[i].categoryId],
                            ),
                            onEdit: filteredTxs[i].sourceType == 'manual'
                                ? () => _showEditTransactionDialog(
                                    context,
                                    ref,
                                    filteredTxs[i],
                                  )
                                : null,
                            category: data.categoriesById[filteredTxs[i].categoryId],
                            onReverse: () => _confirmAndReverseTransaction(
                              context,
                              ref,
                              filteredTxs[i],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<_BukuKasViewData> _loadData(AppDatabase db, String yearMonth) async {
    final allTxs = await db.getActiveTransactions(yearMonth: yearMonth);
    final cats = await db.getActiveCategories();
    final debts = await db.getActiveDebts();

    var income = 0;
    var expense = 0;
    for (final tx in allTxs) {
      if (tx.type == 'income') {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
    }

    return _BukuKasViewData(
      transactions: allTxs,
      categoriesById: {for (final c in cats) c.id: c},
      activeDebts: debts.where((d) => d.remainingAmount > 0).toList(),
      totalIncome: income,
      totalExpense: expense,
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? SwissLedgerColors.textPrimary
              : SwissLedgerColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? SwissLedgerColors.textPrimary
                : SwissLedgerColors.borderHairline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: SwissLedgerTypography.sans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : SwissLedgerColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _BukuKasViewData {
  final List<LocalTransaction> transactions;
  final Map<String, LocalCategory> categoriesById;
  final List<LocalDebt> activeDebts;
  final int totalIncome;
  final int totalExpense;

  const _BukuKasViewData({
    required this.transactions,
    required this.categoriesById,
    required this.activeDebts,
    required this.totalIncome,
    required this.totalExpense,
  });

  int get netBalance => totalIncome - totalExpense;
}

class _LedgerTransactionRow extends StatelessWidget {
  final LocalTransaction tx;
  final LocalCategory? category;
  final VoidCallback onReverse;
  final VoidCallback? onEdit;
  final VoidCallback? onTapRow;

  const _LedgerTransactionRow({
    required this.tx,
    required this.category,
    required this.onReverse,
    this.onEdit,
    this.onTapRow,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == 'income';
    final signedAmount = isIncome
        ? '+${RupiahFormatter.format(tx.amount)}'
        : '-${RupiahFormatter.format(tx.amount)}';

    return InkWell(
      onTap: onTapRow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: SwissLedgerColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                CategoryIconMapper.fromKey(category?.iconKey ?? 'receipt'),
                size: 17,
                color: SwissLedgerColors.textPrimary,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title ?? category?.name ?? 'Transaksi',
                    style: SwissLedgerTypography.sans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SwissLedgerColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${category?.name ?? 'Umum'} · ${RupiahFormatter.formatIsoDate(tx.transactionDate)}',
                    style: SwissLedgerTypography.sans(
                      fontSize: 11,
                      color: SwissLedgerColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  signedAmount,
                  style: SwissLedgerTypography.monoTabular(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isIncome
                        ? SwissLedgerColors.accentTeal
                        : SwissLedgerColors.dangerRed,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onEdit != null) ...[
                      InkWell(
                        key: Key('edit_tx_${tx.id}'),
                        onTap: onEdit,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: SwissLedgerColors.accentTealSubtle,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Ubah',
                            style: SwissLedgerTypography.sans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: SwissLedgerColors.accentTeal,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    InkWell(
                      key: Key('reverse_tx_${tx.id}'),
                      onTap: onReverse,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: SwissLedgerColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Koreksi',
                          style: SwissLedgerTypography.sans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: SwissLedgerColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
