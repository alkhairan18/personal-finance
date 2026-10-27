import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/providers/app_providers.dart';
import 'package:personal_finance/app/theme/swiss_ledger_theme.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/money/rupiah_formatter.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  Future<void> _showCreateWishlistDialog(
      BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    var priority = 'medium';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Tambah Item Wishlist'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Barang'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Target Harga (Rp)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  items: const [
                    DropdownMenuItem(value: 'high', child: Text('Tinggi')),
                    DropdownMenuItem(value: 'medium', child: Text('Sedang')),
                    DropdownMenuItem(value: 'low', child: Text('Rendah')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => priority = v);
                  },
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
              onPressed: () async {
                final target = RupiahFormatter.parseDigits(targetCtrl.text);
                final name = nameCtrl.text.trim();
                if (target <= 0 || name.isEmpty) return;
                final repo = ref.read(wishlistRepositoryProvider);
                if (repo == null) return;
                await repo.createWishlistItem(
                  itemName: name,
                  targetAmount: target,
                  priority: priority,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(activeDatabaseProvider);
    if (db == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<LocalWishlist>>(
      future: db.getActiveWishlistItems(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        final totalTarget =
            items.fold<int>(0, (sum, w) => sum + w.targetAmount);
        final totalSaved =
            items.fold<int>(0, (sum, w) => sum + w.savedAmount);

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
              onPressed: () => _showCreateWishlistDialog(context, ref),
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
            if (items.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: SwissLedgerColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SwissLedgerColors.borderHairline),
                ),
                child: Text(
                  'Belum ada daftar rencana pembelian pada Wishlist.',
                  textAlign: TextAlign.center,
                  style: SwissLedgerTypography.sans(
                    fontSize: 13,
                    color: SwissLedgerColors.textMuted,
                  ),
                ),
              )
            else
              for (final item in items) ...[
                _WishlistCard(item: item),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
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
    final amountCtrl = TextEditingController(text: item.savedAmount.toString());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tabungan ${item.itemName}'),
        content: TextField(
          key: const Key('wishlist_savings_amount_field'),
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Total Dana Terkumpul (Rp)',
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
              final nextSaved = RupiahFormatter.parseDigits(amountCtrl.text);
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
      ),
    );
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            ],
          ),
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
          if (item.status != 'purchased') ...[
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
                    onPressed: () async {
                      final repo = ref.read(wishlistRepositoryProvider);
                      if (repo == null) return;
                      await repo.markPurchased(item.id);
                    },
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
