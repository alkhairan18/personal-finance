import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/providers/app_providers.dart';
import 'package:personal_finance/app/theme/swiss_ledger_theme.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/finance/installment_calculator.dart';
import 'package:personal_finance/core/finance/obligation_status.dart';
import 'package:personal_finance/core/money/rupiah_formatter.dart';

class KewajibanScreen extends ConsumerStatefulWidget {
  const KewajibanScreen({super.key});

  @override
  ConsumerState<KewajibanScreen> createState() => _KewajibanScreenState();
}

class _KewajibanScreenState extends ConsumerState<KewajibanScreen> {
  int _subTabIndex = 0; // 0 = Hutang & Piutang, 1 = Cicilan

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(activeDatabaseProvider);
    if (db == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: SwissLedgerColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: SwissLedgerColors.borderHairline,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SubTabPill(
                    key: const Key('kewajiban_subtab_hutang'),
                    label: 'Hutang & Piutang',
                    selected: _subTabIndex == 0,
                    onTap: () => setState(() => _subTabIndex = 0),
                  ),
                ),
                Expanded(
                  child: _SubTabPill(
                    key: const Key('kewajiban_subtab_cicilan'),
                    label: 'Cicilan',
                    selected: _subTabIndex == 1,
                    onTap: () => setState(() => _subTabIndex = 1),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _subTabIndex == 0
              ? _DebtsSubView(db: db)
              : _InstallmentsSubView(db: db),
        ),
      ],
    );
  }
}

class _SubTabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SubTabPill({
    super.key,
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? SwissLedgerColors.surfaceElevated
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: SwissLedgerTypography.sans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? SwissLedgerColors.textPrimary
                : SwissLedgerColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _DebtsSubView extends ConsumerWidget {
  final AppDatabase db;

  const _DebtsSubView({required this.db});

  Future<void> _showCreateOrEditDebtDialog(
    BuildContext context,
    WidgetRef ref, {
    LocalDebt? existingDebt,
  }) async {
    final counterpartyCtrl = TextEditingController(
      text: existingDebt?.counterpartyName ?? '',
    );
    final amountCtrl = TextEditingController(
      text: existingDebt != null
          ? RupiahFormatter.formatNumberOnly(existingDebt.principalAmount)
          : '',
    );
    final titleCtrl = TextEditingController(text: existingDebt?.title ?? '');
    final dueDateCtrl = TextEditingController(
      text: existingDebt?.dueDate ?? '',
    );
    var direction = existingDebt?.direction ?? 'payable';
    var isSubmitting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            existingDebt == null
                ? 'Catat Hutang / Piutang'
                : 'Ubah Hutang / Piutang',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (existingDebt == null) ...[
                  DropdownButtonFormField<String>(
                    initialValue: direction,
                    items: const [
                      DropdownMenuItem(
                        value: 'payable',
                        child: Text('Hutang'),
                      ),
                      DropdownMenuItem(
                        value: 'receivable',
                        child: Text('Piutang'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => direction = v);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: counterpartyCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Pihak'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [RupiahInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Nominal Pokok (Rp)',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dueDateCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Tanggal Jatuh Tempo (Opsional)',
                    hintText: 'Pilih tanggal...',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dueDateCtrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              PhosphorIconsRegular.xCircle,
                              size: 16,
                            ),
                            onPressed: () =>
                                setModalState(() => dueDateCtrl.clear()),
                          ),
                        IconButton(
                          icon: const Icon(
                            PhosphorIconsRegular.calendarBlank,
                            size: 16,
                          ),
                          onPressed: () async {
                            final initial =
                                DateTime.tryParse(dueDateCtrl.text.trim()) ??
                                DateTime.now().add(const Duration(days: 7));
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: initial,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setModalState(() {
                                dueDateCtrl.text = picked
                                    .toIso8601String()
                                    .substring(0, 10);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan (Opsional)',
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
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final amount = RupiahFormatter.parseDigits(
                        amountCtrl.text,
                      );
                      final name = counterpartyCtrl.text.trim();
                      if (amount <= 0 || name.isEmpty) {
                        setModalState(() {
                          errorText =
                              'Nama pihak dan nominal (lebih dari Rp 0) wajib diisi.';
                        });
                        return;
                      }
                      setModalState(() => isSubmitting = true);
                      final repo = ref.read(debtRepositoryProvider);
                      if (repo == null) return;
                      final dueIso = dueDateCtrl.text.trim().isEmpty
                          ? null
                          : dueDateCtrl.text.trim();
                      final cleanTitle = titleCtrl.text.trim().isEmpty
                          ? null
                          : titleCtrl.text.trim();

                      if (existingDebt == null) {
                        final todayIso = DateTime.now()
                            .toIso8601String()
                            .substring(0, 10);
                        await repo.createDebt(
                          direction: direction,
                          counterpartyName: name,
                          principalAmount: amount,
                          startDate: todayIso,
                          dueDate: dueIso,
                          title: cleanTitle,
                        );
                      } else {
                        await repo.updateDebt(
                          debtId: existingDebt.id,
                          counterpartyName: name,
                          principalAmount: amount,
                          dueDate: dueIso,
                          title: cleanTitle,
                        );
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<LocalDebt>>(
      future: db.getActiveDebts(),
      builder: (context, snapshot) {
        final debts = snapshot.data ?? const [];
        var totalPayable = 0;
        var totalReceivable = 0;
        for (final d in debts) {
          if (d.direction == 'payable') {
            totalPayable += d.remainingAmount;
          } else {
            totalReceivable += d.remainingAmount;
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SwissLedgerColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SwissLedgerColors.borderHairline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SISA HUTANG',
                          style: SwissLedgerTypography.sans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: SwissLedgerColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          RupiahFormatter.format(totalPayable),
                          style: SwissLedgerTypography.monoTabular(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: SwissLedgerColors.warningAmber,
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
                          'SISA PIUTANG',
                          style: SwissLedgerTypography.sans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: SwissLedgerColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          RupiahFormatter.format(totalReceivable),
                          style: SwissLedgerTypography.monoTabular(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: SwissLedgerColors.accentTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('add_debt_button'),
              onPressed: () => _showCreateOrEditDebtDialog(context, ref),
              icon: const Icon(PhosphorIconsRegular.plus, size: 15),
              label: Text(
                'Tambah Hutang / Piutang',
                style: SwissLedgerTypography.sans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (debts.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: SwissLedgerColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SwissLedgerColors.borderHairline),
                ),
                child: Text(
                  'Belum ada catatan hutang atau piutang aktif.',
                  textAlign: TextAlign.center,
                  style: SwissLedgerTypography.sans(
                    fontSize: 13,
                    color: SwissLedgerColors.textMuted,
                  ),
                ),
              )
            else
              for (final debt in debts) ...[
                _DebtCard(
                  debt: debt,
                  onEdit: () => _showCreateOrEditDebtDialog(
                    context,
                    ref,
                    existingDebt: debt,
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

class _DebtCard extends ConsumerWidget {
  final LocalDebt debt;
  final VoidCallback onEdit;

  const _DebtCard({
    required this.debt,
    required this.onEdit,
  });

  Future<void> _showDebtPaymentHistorySheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final db = ref.read(activeDatabaseProvider);
    if (db == null) return;
    final payments = await db.getPaymentsForDebt(debt.id);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
              const SizedBox(height: 14),
              Text(
                'Riwayat Pembayaran · ${debt.counterpartyName}',
                style: SwissLedgerTypography.sans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Belum ada riwayat pembayaran untuk kewajiban ini.',
                    style: SwissLedgerTypography.sans(
                      fontSize: 12,
                      color: SwissLedgerColors.textMuted,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: payments.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: SwissLedgerColors.borderHairline,
                    ),
                    itemBuilder: (_, idx) {
                      final p = payments[idx];
                      final isReversed = p.status == 'reversed';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    RupiahFormatter.format(p.amount),
                                    style: SwissLedgerTypography.monoTabular(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isReversed
                                          ? SwissLedgerColors.textMuted
                                          : SwissLedgerColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${RupiahFormatter.formatIsoDate(p.paymentDate)} · ${isReversed ? 'Dikoreksi' : 'Tercatat'}',
                                    style: SwissLedgerTypography.sans(
                                      fontSize: 11,
                                      color: SwissLedgerColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isReversed && p.linkedTransactionId != null)
                              TextButton(
                                onPressed: () async {
                                  final txRepo = ref.read(
                                    transactionRepositoryProvider,
                                  );
                                  if (txRepo == null) return;
                                  await txRepo.reverseTransaction(
                                    originalTransactionId:
                                        p.linkedTransactionId!,
                                    reversalDate: DateTime.now()
                                        .toIso8601String()
                                        .substring(0, 10),
                                    notes:
                                        'Koreksi pembayaran ${debt.counterpartyName}',
                                  );
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                },
                                child: Text(
                                  'Koreksi',
                                  style: SwissLedgerTypography.sans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: SwissLedgerColors.dangerRed,
                                  ),
                                ),
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
      ),
    );
  }

  Future<void> _showPartialPayDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final amountCtrl = TextEditingController(
      text: RupiahFormatter.formatNumberOnly(debt.remainingAmount),
    );
    final dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    var isSubmitting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text('Bayar ${debt.counterpartyName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sisa kewajiban saat ini: ${RupiahFormatter.format(debt.remainingAmount)}',
                  style: SwissLedgerTypography.sans(
                    fontSize: 12,
                    color: SwissLedgerColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [RupiahInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Nominal Bayar (Rp)',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dateCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Tanggal Pembayaran',
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
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final amt = RupiahFormatter.parseDigits(amountCtrl.text);
                      if (amt <= 0 || amt > debt.remainingAmount) {
                        setModalState(() {
                          errorText =
                              'Nominal bayar harus antara Rp 1 dan ${RupiahFormatter.format(debt.remainingAmount)}.';
                        });
                        return;
                      }
                      setModalState(() => isSubmitting = true);
                      final repo = ref.read(debtRepositoryProvider);
                      if (repo == null) return;
                      await repo.recordPayment(
                        debtId: debt.id,
                        amount: amt,
                        paymentDate: dateCtrl.text.trim(),
                        notes: 'Pembayaran kewajiban',
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
              child: const Text('Simpan Pembayaran'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmArchiveDebt(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan Kewajiban'),
        content: Text(
          'Hapus catatan "${debt.counterpartyName}" dari daftar kewajiban aktif?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SwissLedgerColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(debtRepositoryProvider);
    await repo?.archiveDebt(debt.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final derivedStatus = ObligationStatusCalculator.deriveFromIso(
      remainingAmount: debt.remainingAmount,
      dueDateIso: debt.dueDate,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SwissLedgerColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SwissLedgerColors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  debt.counterpartyName,
                  style: SwissLedgerTypography.sans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: derivedStatus == ObligationStatus.paid
                      ? SwissLedgerColors.accentTealSubtle
                      : SwissLedgerColors.warningSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  derivedStatus.label,
                  style: SwissLedgerTypography.sans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: derivedStatus == ObligationStatus.paid
                        ? SwissLedgerColors.accentTeal
                        : SwissLedgerColors.warningAmber,
                  ),
                ),
              ),
            ],
          ),
          if (debt.title != null && debt.title!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              debt.title!,
              style: SwissLedgerTypography.sans(
                fontSize: 12,
                color: SwissLedgerColors.textMuted,
              ),
            ),
          ],
          if (debt.dueDate != null && debt.dueDate!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Jatuh tempo: ${RupiahFormatter.formatIsoDate(debt.dueDate!)}',
              style: SwissLedgerTypography.sans(
                fontSize: 11,
                color: SwissLedgerColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SISA KEWAJIBAN',
                    style: SwissLedgerTypography.sans(
                      fontSize: 10,
                      color: SwissLedgerColors.textMuted,
                    ),
                  ),
                  Text(
                    RupiahFormatter.format(debt.remainingAmount),
                    style: SwissLedgerTypography.monoTabular(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    key: Key('debt_history_${debt.id}'),
                    tooltip: 'Riwayat Pembayaran',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        _showDebtPaymentHistorySheet(context, ref),
                    icon: const Icon(
                      PhosphorIconsRegular.clockCounterClockwise,
                      size: 16,
                      color: SwissLedgerColors.textMuted,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ubah',
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                    icon: const Icon(
                      PhosphorIconsRegular.pencilSimple,
                      size: 16,
                      color: SwissLedgerColors.textMuted,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hapus',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmArchiveDebt(context, ref),
                    icon: const Icon(
                      PhosphorIconsRegular.trash,
                      size: 16,
                      color: SwissLedgerColors.dangerRed,
                    ),
                  ),
                  if (debt.remainingAmount > 0)
                    OutlinedButton(
                      onPressed: () => _showPartialPayDialog(context, ref),
                      child: Text(
                        'Bayar / Cicil',
                        style: SwissLedgerTypography.sans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: SwissLedgerColors.accentTeal,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InstallmentsSubView extends ConsumerWidget {
  final AppDatabase db;

  const _InstallmentsSubView({required this.db});

  Future<void> _showCreatePlanDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final titleCtrl = TextEditingController();
    final totalCtrl = TextEditingController(text: '6.000.000');
    final countCtrl = TextEditingController(text: '7');
    var isSubmitting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final total = RupiahFormatter.parseDigits(totalCtrl.text);
          final count = int.tryParse(countCtrl.text.trim()) ?? 0;
          final preview = (total > 0 && count > 0)
              ? InstallmentCalculator.generateSchedule(
                  totalAmount: total,
                  count: count,
                  frequency: 'monthly',
                  startDate: DateTime.now(),
                )
              : const <PlannedInstallmentTerm>[];

          return AlertDialog(
            title: const Text('Buat Rencana Cicilan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Cicilan',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: totalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [RupiahInputFormatter()],
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Total Nominal (Rp)',
                      prefixText: 'Rp ',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Jumlah Termin (contoh: 7)',
                    ),
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Simulasi: Termin #1 ${RupiahFormatter.format(preview.first.plannedAmount)} | Termin #${preview.last.installmentNumber} ${RupiahFormatter.format(preview.last.plannedAmount)}',
                      style: SwissLedgerTypography.monoTabular(
                        fontSize: 11,
                        color: SwissLedgerColors.accentTeal,
                      ),
                    ),
                  ],
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
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (total <= 0 ||
                            count <= 0 ||
                            titleCtrl.text.trim().isEmpty) {
                          setModalState(() {
                            errorText =
                                'Nama cicilan, total nominal, dan jumlah termin wajib diisi.';
                          });
                          return;
                        }
                        setModalState(() => isSubmitting = true);
                        final repo = ref.read(installmentRepositoryProvider);
                        if (repo == null) return;
                        final todayIso = DateTime.now()
                            .toIso8601String()
                            .substring(0, 10);
                        await repo.createPlanWithSchedule(
                          title: titleCtrl.text.trim(),
                          totalAmount: total,
                          installmentCount: count,
                          frequency: 'monthly',
                          startDate: todayIso,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                child: const Text('Simpan Jadwal'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<_PlanWithTerms>>(
      future: _loadPlans(db),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            OutlinedButton.icon(
              key: const Key('add_installment_plan_button'),
              onPressed: () => _showCreatePlanDialog(context, ref),
              icon: const Icon(PhosphorIconsRegular.plus, size: 15),
              label: Text(
                'Buat Rencana Cicilan Baru',
                style: SwissLedgerTypography.sans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: SwissLedgerColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SwissLedgerColors.borderHairline),
                ),
                child: Text(
                  'Belum ada rencana cicilan aktif.',
                  textAlign: TextAlign.center,
                  style: SwissLedgerTypography.sans(
                    fontSize: 13,
                    color: SwissLedgerColors.textMuted,
                  ),
                ),
              )
            else
              for (final item in items) ...[
                _InstallmentPlanCard(item: item),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }

  Future<List<_PlanWithTerms>> _loadPlans(AppDatabase db) async {
    final plans = await db.getActiveInstallmentPlans();
    final result = <_PlanWithTerms>[];
    for (final plan in plans) {
      final terms = await db.getInstallmentsForPlan(plan.id);
      result.add(_PlanWithTerms(plan: plan, terms: terms));
    }
    return result;
  }
}

class _PlanWithTerms {
  final LocalInstallmentPlan plan;
  final List<LocalInstallment> terms;

  const _PlanWithTerms({
    required this.plan,
    required this.terms,
  });

  int get paidTermsCount => terms.where((t) => t.status == 'paid').length;
  int get totalRemaining =>
      terms.fold<int>(0, (sum, t) => sum + t.remainingAmount);
  LocalInstallment? get nextUnpaidTerm =>
      terms.where((t) => t.remainingAmount > 0).firstOrNull;
}

class _InstallmentPlanCard extends ConsumerWidget {
  final _PlanWithTerms item;

  const _InstallmentPlanCard({required this.item});

  Future<void> _showPlanPaymentHistorySheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final db = ref.read(activeDatabaseProvider);
    if (db == null) return;
    final payments = await db.getPaymentsForPlan(item.plan.id);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
              const SizedBox(height: 14),
              Text(
                'Riwayat Pembayaran · ${item.plan.title}',
                style: SwissLedgerTypography.sans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Belum ada riwayat pembayaran termin untuk cicilan ini.',
                    style: SwissLedgerTypography.sans(
                      fontSize: 12,
                      color: SwissLedgerColors.textMuted,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: payments.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: SwissLedgerColors.borderHairline,
                    ),
                    itemBuilder: (_, idx) {
                      final p = payments[idx];
                      final isReversed = p.status == 'reversed';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    RupiahFormatter.format(p.amount),
                                    style: SwissLedgerTypography.monoTabular(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isReversed
                                          ? SwissLedgerColors.textMuted
                                          : SwissLedgerColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${RupiahFormatter.formatIsoDate(p.paymentDate)} · ${isReversed ? 'Dikoreksi' : 'Tercatat'}',
                                    style: SwissLedgerTypography.sans(
                                      fontSize: 11,
                                      color: SwissLedgerColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isReversed && p.linkedTransactionId != null)
                              TextButton(
                                onPressed: () async {
                                  final txRepo = ref.read(
                                    transactionRepositoryProvider,
                                  );
                                  if (txRepo == null) return;
                                  await txRepo.reverseTransaction(
                                    originalTransactionId:
                                        p.linkedTransactionId!,
                                    reversalDate: DateTime.now()
                                        .toIso8601String()
                                        .substring(0, 10),
                                    notes:
                                        'Koreksi pembayaran ${item.plan.title}',
                                  );
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                },
                                child: Text(
                                  'Koreksi',
                                  style: SwissLedgerTypography.sans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: SwissLedgerColors.dangerRed,
                                  ),
                                ),
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
      ),
    );
  }

  Future<void> _showEditPlanDialog(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController(text: item.plan.title);
    final vendorCtrl = TextEditingController(text: item.plan.vendorName ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Rencana Cicilan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Nama Cicilan'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: vendorCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Toko / Penyedia (Opsional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              final repo = ref.read(installmentRepositoryProvider);
              await repo?.updatePlan(
                planId: item.plan.id,
                title: title,
                vendorName: vendorCtrl.text.trim().isEmpty
                    ? null
                    : vendorCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmArchivePlan(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Rencana Cicilan'),
        content: Text('Hapus rencana cicilan "${item.plan.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SwissLedgerColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(installmentRepositoryProvider);
    await repo?.archivePlan(item.plan.id);
  }

  Future<void> _showPayTermDialog(
    BuildContext context,
    WidgetRef ref,
    LocalInstallment nextTerm,
  ) async {
    final amountCtrl = TextEditingController(
      text: RupiahFormatter.formatNumberOnly(nextTerm.remainingAmount),
    );
    final dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    var isSubmitting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text('Bayar Termin #${nextTerm.installmentNumber}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${item.plan.title} · Sisa termin: ${RupiahFormatter.format(nextTerm.remainingAmount)}',
                  style: SwissLedgerTypography.sans(
                    fontSize: 12,
                    color: SwissLedgerColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('installment_pay_amount_field'),
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [RupiahInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Nominal Pembayaran (Rp)',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dateCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Tanggal Pembayaran',
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
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              key: const Key('installment_pay_submit_button'),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final amt = RupiahFormatter.parseDigits(amountCtrl.text);
                      if (amt <= 0 || amt > nextTerm.remainingAmount) {
                        setModalState(() {
                          errorText =
                              'Nominal bayar harus antara Rp 1 dan ${RupiahFormatter.format(nextTerm.remainingAmount)}.';
                        });
                        return;
                      }
                      setModalState(() => isSubmitting = true);
                      final repo = ref.read(installmentRepositoryProvider);
                      if (repo == null) return;
                      await repo.recordPayment(
                        installmentId: nextTerm.id,
                        amount: amt,
                        paymentDate: dateCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
              child: const Text('Simpan Pembayaran'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = item.plan;
    final nextTerm = item.nextUnpaidTerm;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SwissLedgerColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SwissLedgerColors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: SwissLedgerTypography.sans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (plan.vendorName != null && plan.vendorName!.isNotEmpty)
                      Text(
                        plan.vendorName!,
                        style: SwissLedgerTypography.sans(
                          fontSize: 11,
                          color: SwissLedgerColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SwissLedgerColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.paidTermsCount}/${plan.installmentCount} Termin',
                  style: SwissLedgerTypography.monoTabular(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SwissLedgerColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < item.terms.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: item.terms[i].status == 'paid'
                          ? SwissLedgerColors.accentTeal
                          : (item.terms[i].status == 'partial'
                                ? SwissLedgerColors.warningAmber
                                : SwissLedgerColors.surfaceSubtle),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SISA TOTAL CICILAN',
                      style: SwissLedgerTypography.sans(
                        fontSize: 10,
                        color: SwissLedgerColors.textMuted,
                      ),
                    ),
                    Text(
                      RupiahFormatter.format(item.totalRemaining),
                      overflow: TextOverflow.ellipsis,
                      style: SwissLedgerTypography.monoTabular(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (nextTerm != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'TERMIN #${nextTerm.installmentNumber} (${RupiahFormatter.formatIsoDate(nextTerm.dueDate)})',
                        overflow: TextOverflow.ellipsis,
                        style: SwissLedgerTypography.sans(
                          fontSize: 10,
                          color: SwissLedgerColors.textMuted,
                        ),
                      ),
                      Text(
                        RupiahFormatter.format(nextTerm.remainingAmount),
                        overflow: TextOverflow.ellipsis,
                        style: SwissLedgerTypography.monoTabular(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: SwissLedgerColors.accentTeal,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                key: Key('plan_history_${plan.id}'),
                tooltip: 'Riwayat Pembayaran',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showPlanPaymentHistorySheet(context, ref),
                icon: const Icon(
                  PhosphorIconsRegular.clockCounterClockwise,
                  size: 16,
                  color: SwissLedgerColors.textMuted,
                ),
              ),
              IconButton(
                tooltip: 'Ubah Cicilan',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showEditPlanDialog(context, ref),
                icon: const Icon(
                  PhosphorIconsRegular.pencilSimple,
                  size: 16,
                  color: SwissLedgerColors.textMuted,
                ),
              ),
              IconButton(
                tooltip: 'Hapus Cicilan',
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmArchivePlan(context, ref),
                icon: const Icon(
                  PhosphorIconsRegular.trash,
                  size: 16,
                  color: SwissLedgerColors.dangerRed,
                ),
              ),
              if (nextTerm != null) ...[
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => _showPayTermDialog(context, ref, nextTerm),
                  child: Text(
                    'Bayar Termin #${nextTerm.installmentNumber}',
                    style: SwissLedgerTypography.sans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SwissLedgerColors.accentTeal,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
