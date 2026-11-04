import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/providers/app_providers.dart';
import 'package:personal_finance/app/theme/swiss_ledger_theme.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/money/rupiah_formatter.dart';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  static Future<void> showCreateOrEditWishlistDialog(
    BuildContext context,
    WidgetRef ref, {
    LocalWishlist? existingItem,
  }) async {
    final isEdit = existingItem != null;
    final nameCtrl = TextEditingController(text: existingItem?.itemName ?? '');
    final targetCtrl = TextEditingController(
      text: existingItem != null
          ? RupiahFormatter.formatNumberOnly(existingItem.targetAmount)
          : '',
    );
    final targetDateCtrl = TextEditingController(
      text: existingItem?.targetDate ?? '',
    );
    final notesCtrl = TextEditingController(text: existingItem?.notes ?? '');
    var priority = existingItem?.priority ?? 'medium';
    var isSubmitting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            isEdit ? 'Ubah Rencana Wishlist' : 'Tambah Item Wishlist',
            style: SwissLedgerTypography.sans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Barang / Rencana',
                    hintText: 'Contoh: Monitor Kerja 27 Inci',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [RupiahInputFormatter()],
                  style: SwissLedgerTypography.monoTabular(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Target Harga (Rp)',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(
                    labelText: 'Tingkat Prioritas',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'high',
                      child: Text('Prioritas Tinggi'),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('Prioritas Sedang'),
                    ),
                    DropdownMenuItem(
                      value: 'low',
                      child: Text('Prioritas Rendah'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => priority = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: targetDateCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Tanggal Target (Opsional)',
                    hintText: 'Pilih tanggal target...',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (targetDateCtrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              PhosphorIconsRegular.xCircle,
                              size: 16,
                            ),
                            onPressed: () =>
                                setModalState(() => targetDateCtrl.clear()),
                          ),
                        IconButton(
                          icon: const Icon(
                            PhosphorIconsRegular.calendarBlank,
                            size: 16,
                          ),
                          onPressed: () async {
                            final initial =
                                DateTime.tryParse(targetDateCtrl.text.trim()) ??
                                DateTime.now().add(const Duration(days: 30));
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: initial,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setModalState(() {
                                targetDateCtrl.text = picked
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
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Catatan / Referensi (Opsional)',
                    hintText: 'Link toko atau spesifikasi...',
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style: SwissLedgerTypography.sans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
                      final target = RupiahFormatter.parseDigits(
                        targetCtrl.text,
                      );
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        setModalState(() {
                          errorText = 'Nama barang tidak boleh kosong.';
                        });
                        return;
                      }
                      if (target <= 0) {
                        setModalState(() {
                          errorText = 'Target harga harus lebih dari Rp 0.';
                        });
                        return;
                      }
                      setModalState(() => isSubmitting = true);
                      final repo = ref.read(wishlistRepositoryProvider);
                      if (repo == null) return;
                      final targetDate = targetDateCtrl.text.trim().isEmpty
                          ? null
                          : targetDateCtrl.text.trim();
                      final notes = notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim();
                      if (isEdit) {
                        await repo.updateWishlistItem(
                          wishlistId: existingItem.id,
                          itemName: name,
                          targetAmount: target,
                          priority: priority,
                          targetDate: targetDate,
                          notes: notes,
                          updateOptionalFields: true,
                        );
                      } else {
                        await repo.createWishlistItem(
                          itemName: name,
                          targetAmount: target,
                          priority: priority,
                          targetDate: targetDate,
                          notes: notes,
                        );
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
              child: Text(isEdit ? 'Simpan Perubahan' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  String _selectedFilter = 'all';

  bool _matchesFilter(LocalWishlist item) {
    switch (_selectedFilter) {
      case 'active':
        return item.status != 'purchased' && item.status != 'cancelled';
      case 'high':
        return item.priority == 'high' &&
            item.status != 'purchased' &&
            item.status != 'cancelled';
      case 'purchased':
        return item.status == 'purchased';
      case 'cancelled':
        return item.status == 'cancelled';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(activeDatabaseProvider);
    if (db == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<LocalWishlist>>(
      future: db.getAllNonArchivedWishlistItems(),
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? const [];
        final activePlanningItems = allItems
            .where((w) => w.status != 'cancelled')
            .toList();
        final totalTarget = activePlanningItems.fold<int>(
          0,
          (sum, w) => sum + w.targetAmount,
        );
        final totalSaved = activePlanningItems.fold<int>(
          0,
          (sum, w) => sum + w.savedAmount,
        );
        final filteredItems = allItems.where(_matchesFilter).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SwissLedgerColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SwissLedgerColors.borderHairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PERENCANAAN WISHLIST (TERPISAH DARI SALDO KAS)',
                    style: SwissLedgerTypography.sans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: SwissLedgerColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL TARGET',
                              style: SwissLedgerTypography.sans(
                                fontSize: 10,
                                color: SwissLedgerColors.textMuted,
                              ),
                            ),
                            Text(
                              RupiahFormatter.format(totalTarget),
                              style: SwissLedgerTypography.monoTabular(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
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
                              'TERKUMPUL',
                              style: SwissLedgerTypography.sans(
                                fontSize: 10,
                                color: SwissLedgerColors.textMuted,
                              ),
                            ),
                            Text(
                              RupiahFormatter.format(totalSaved),
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
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('add_wishlist_button'),
              onPressed: () =>
                  WishlistScreen.showCreateOrEditWishlistDialog(context, ref),
              icon: const Icon(PhosphorIconsRegular.plus, size: 15),
              label: Text(
                'Tambah Rencana Wishlist',
                style: SwissLedgerTypography.sans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _WishlistFilterChip(
                    chipKey: const Key('wishlist_filter_all'),
                    label: 'Semua',
                    selected: _selectedFilter == 'all',
                    onTap: () => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 6),
                  _WishlistFilterChip(
                    chipKey: const Key('wishlist_filter_active'),
                    label: 'Aktif',
                    selected: _selectedFilter == 'active',
                    onTap: () => setState(() => _selectedFilter = 'active'),
                  ),
                  const SizedBox(width: 6),
                  _WishlistFilterChip(
                    chipKey: const Key('wishlist_filter_high'),
                    label: 'Prioritas Tinggi',
                    selected: _selectedFilter == 'high',
                    onTap: () => setState(() => _selectedFilter = 'high'),
                  ),
                  const SizedBox(width: 6),
                  _WishlistFilterChip(
                    chipKey: const Key('wishlist_filter_purchased'),
                    label: 'Dibeli',
                    selected: _selectedFilter == 'purchased',
                    onTap: () => setState(() => _selectedFilter = 'purchased'),
                  ),
                  const SizedBox(width: 6),
                  _WishlistFilterChip(
                    chipKey: const Key('wishlist_filter_cancelled'),
                    label: 'Dibatalkan',
                    selected: _selectedFilter == 'cancelled',
                    onTap: () => setState(() => _selectedFilter = 'cancelled'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (filteredItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: SwissLedgerColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SwissLedgerColors.borderHairline),
                ),
                child: Column(
                  children: [
                    Text(
                      allItems.isEmpty
                          ? 'Belum ada daftar rencana pembelian pada Wishlist.'
                          : 'Tidak ada item Wishlist yang sesuai dengan filter terpilih.',
                      textAlign: TextAlign.center,
                      style: SwissLedgerTypography.sans(
                        fontSize: 13,
                        color: SwissLedgerColors.textMuted,
                      ),
                    ),
                    if (allItems.isEmpty) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () =>
                            WishlistScreen.showCreateOrEditWishlistDialog(
                              context,
                              ref,
                            ),
                        icon: const Icon(PhosphorIconsRegular.plus, size: 14),
                        label: const Text('Buat Rencana Pertama'),
                      ),
                    ],
                  ],
                ),
              )
            else
              for (final item in filteredItems) ...[
                _WishlistCard(item: item),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

class _WishlistFilterChip extends StatelessWidget {
  final Key chipKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WishlistFilterChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: chipKey,
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

class _WishlistCard extends ConsumerWidget {
  final LocalWishlist item;

  const _WishlistCard({required this.item});

  Future<void> _showUpdateSavingsDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final amountCtrl = TextEditingController(
      text: RupiahFormatter.formatNumberOnly(item.savedAmount),
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final currentVal = RupiahFormatter.parseDigits(amountCtrl.text);
          final remaining = (item.targetAmount - currentVal).clamp(
            0,
            item.targetAmount,
          );
          return AlertDialog(
            title: Text(
              'Tabungan ${item.itemName}',
              style: SwissLedgerTypography.sans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SwissLedgerColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target: ${RupiahFormatter.format(item.targetAmount)}',
                          style: SwissLedgerTypography.monoTabular(
                            fontSize: 11,
                            color: SwissLedgerColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kurang: ${RupiahFormatter.format(remaining)}',
                          style: SwissLedgerTypography.monoTabular(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: SwissLedgerColors.accentTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'TAMBAH CEPAT KE TABUNGAN',
                    style: SwissLedgerTypography.sans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: SwissLedgerColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final delta in const [
                        50000,
                        100000,
                        250000,
                        500000,
                      ])
                        InkWell(
                          onTap: () {
                            final base = RupiahFormatter.parseDigits(
                              amountCtrl.text,
                            );
                            final updated = base + delta;
                            final formatted = RupiahFormatter.formatNumberOnly(
                              updated,
                            );
                            amountCtrl.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                            );
                            setModalState(() {});
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: SwissLedgerColors.accentTealSubtle,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: SwissLedgerColors.accentTeal,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '+${RupiahFormatter.format(delta)}',
                              style: SwissLedgerTypography.monoTabular(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: SwissLedgerColors.accentTeal,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('wishlist_savings_amount_field'),
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [RupiahInputFormatter()],
                    onChanged: (_) => setModalState(() {}),
                    style: SwissLedgerTypography.monoTabular(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Total Dana Terkumpul (Rp)',
                      prefixText: 'Rp ',
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
                key: const Key('wishlist_savings_submit_button'),
                onPressed: () async {
                  final nextSaved = RupiahFormatter.parseDigits(
                    amountCtrl.text,
                  );
                  final repo = ref.read(wishlistRepositoryProvider);
                  if (repo == null) return;
                  await repo.updateSavedAmount(
                    wishlistId: item.id,
                    newSavedAmount: nextSaved,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Simpan Tabungan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmArchiveWishlist(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Rencana Wishlist?'),
        content: Text(
          'Rencana "${item.itemName}" akan diarsipkan dari daftar Wishlist.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SwissLedgerColors.dangerRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = ref.read(wishlistRepositoryProvider);
      if (repo != null) {
        await repo.archiveWishlistItem(item.id);
      }
    }
  }

  Future<void> _confirmMarkPurchased(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tandai Sudah Dibeli?'),
        content: Text(
          'Tandai "${item.itemName}" sebagai sudah dibeli? Status perencanaan akan selesai tanpa memotong saldo Buku Kas secara otomatis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Tandai Dibeli'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = ref.read(wishlistRepositoryProvider);
      if (repo != null) {
        await repo.markPurchased(item.id);
      }
    }
  }

  Future<void> _confirmMarkCancelled(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Rencana Wishlist?'),
        content: Text(
          'Ubah status "${item.itemName}" menjadi Dibatalkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Kembali'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SwissLedgerColors.warningAmber,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = ref.read(wishlistRepositoryProvider);
      if (repo != null) {
        await repo.markCancelled(item.id);
      }
    }
  }

  String _priorityLabel(String p) {
    switch (p) {
      case 'high':
        return 'Prioritas Tinggi';
      case 'low':
        return 'Prioritas Rendah';
      default:
        return 'Prioritas Sedang';
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'purchased':
        return 'Dibeli';
      case 'cancelled':
        return 'Dibatalkan';
      case 'ready_to_buy':
        return 'Siap Dibeli';
      case 'saving':
        return 'Ditabung';
      default:
        return 'Direncanakan';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressRatio = item.targetAmount > 0
        ? (item.savedAmount / item.targetAmount).clamp(0.0, 1.0)
        : 0.0;

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
            children: [
              Expanded(
                child: Text(
                  item.itemName,
                  style: SwissLedgerTypography.sans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: SwissLedgerColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_priorityLabel(item.priority)} · ${_statusLabel(item.status)}',
                    overflow: TextOverflow.ellipsis,
                    style: SwissLedgerTypography.sans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: SwissLedgerColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => WishlistScreen.showCreateOrEditWishlistDialog(
                  context,
                  ref,
                  existingItem: item,
                ),
                icon: const Icon(
                  PhosphorIconsRegular.pencilSimple,
                  size: 15,
                  color: SwissLedgerColors.textMuted,
                ),
                tooltip: 'Ubah Wishlist',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                onPressed: () => _confirmArchiveWishlist(context, ref),
                icon: const Icon(
                  PhosphorIconsRegular.trash,
                  size: 15,
                  color: SwissLedgerColors.dangerRed,
                ),
                tooltip: 'Hapus Wishlist',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          if ((item.targetDate != null && item.targetDate!.isNotEmpty) ||
              (item.notes != null && item.notes!.isNotEmpty)) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (item.targetDate != null && item.targetDate!.isNotEmpty)
                  'Target: ${RupiahFormatter.formatIsoDate(item.targetDate!)}',
                if (item.notes != null && item.notes!.isNotEmpty) item.notes!,
              ].join(' · '),
              style: SwissLedgerTypography.sans(
                fontSize: 11,
                color: SwissLedgerColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progressRatio,
              minHeight: 6,
              backgroundColor: SwissLedgerColors.surfaceSubtle,
              color: SwissLedgerColors.accentTeal,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Terkumpul ${RupiahFormatter.format(item.savedAmount)}',
                  overflow: TextOverflow.ellipsis,
                  style: SwissLedgerTypography.monoTabular(
                    fontSize: 11,
                    color: SwissLedgerColors.accentTeal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Target ${RupiahFormatter.format(item.targetAmount)}',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: SwissLedgerTypography.monoTabular(
                    fontSize: 11,
                    color: SwissLedgerColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (item.status != 'purchased' && item.status != 'cancelled') ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton(
                    key: Key('wishlist_add_savings_${item.id}'),
                    onPressed: () => _showUpdateSavingsDialog(context, ref),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(
                      'Tambah Tabungan',
                      style: SwissLedgerTypography.sans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SwissLedgerColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _confirmMarkCancelled(context, ref),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      'Batalkan',
                      style: SwissLedgerTypography.sans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: SwissLedgerColors.textMuted,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _confirmMarkPurchased(context, ref),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(
                      'Tandai Dibeli',
                      style: SwissLedgerTypography.sans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SwissLedgerColors.accentTeal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
