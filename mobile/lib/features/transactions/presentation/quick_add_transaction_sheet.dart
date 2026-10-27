import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/providers/app_providers.dart';
import 'package:personal_finance/app/theme/swiss_ledger_theme.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/money/rupiah_formatter.dart';

class QuickAddTransactionSheet extends ConsumerStatefulWidget {
  const QuickAddTransactionSheet({super.key});

  @override
  ConsumerState<QuickAddTransactionSheet> createState() =>
      _QuickAddTransactionSheetState();
}

class _QuickAddTransactionSheetState
    extends ConsumerState<QuickAddTransactionSheet> {
  String _selectedType = 'expense';
  String _digitBuffer = '';
  String? _selectedCategoryId;
  String _selectedPaymentMethod = 'QRIS / E-Wallet';
  late DateTime _selectedDate;
  final _titleController = TextEditingController();
  List<LocalCategory> _categories = const [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final db = ref.read(activeDatabaseProvider);
    if (db == null) return;
    final cats = await db.getActiveCategories(kind: _selectedType);
    if (!mounted) return;
    setState(() {
      _categories = cats;
      if (_categories.isNotEmpty &&
          !_categories.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = _categories.first.id;
      }
    });
  }

  int get _amount =>
      _digitBuffer.isEmpty ? 0 : (int.tryParse(_digitBuffer) ?? 0);

  void _appendDigits(String digits) {
    setState(() {
      if (_digitBuffer.isEmpty && (digits == '0' || digits == '000')) {
        return;
      }
      final next = '$_digitBuffer$digits';
      if (next.length <= 12) {
        _digitBuffer = next;
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_digitBuffer.isNotEmpty) {
        _digitBuffer = _digitBuffer.substring(0, _digitBuffer.length - 1);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final nameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Kategori Baru'),
        content: TextField(
          key: const Key('new_category_name_input'),
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nama Kategori',
            hintText: 'Contoh: Kopi & Camilan',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            key: const Key('save_new_category_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SwissLedgerColors.accentTeal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final repo = ref.read(transactionRepositoryProvider);
              final name = nameCtrl.text.trim();
              if (repo == null || name.isEmpty) return;
              final newId = await repo.createCustomCategory(
                name: name,
                kind: _selectedType,
              );
              await _loadCategories();
              if (mounted) {
                setState(() => _selectedCategoryId = newId);
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitTransaction() async {
    final amount = _amount;
    if (amount <= 0) return;

    final txRepo = ref.read(transactionRepositoryProvider);
    if (txRepo == null) return;

    final rawTitle = _titleController.text.trim();
    final selectedCat = _categories
        .where((c) => c.id == _selectedCategoryId)
        .firstOrNull;
    final effectiveTitle =
        rawTitle.isNotEmpty ? rawTitle : (selectedCat?.name ?? 'Transaksi');
    final dateStr =
        '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    await txRepo.createTransaction(
      type: _selectedType,
      amount: amount,
      categoryId: _selectedCategoryId,
      transactionDate: dateStr,
      title: effectiveTitle,
      notes: 'Metode: $_selectedPaymentMethod',
    );

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDigits = RupiahFormatter.formatNumberOnly(_amount);
    final dateIso =
        '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: const BoxDecoration(
        color: SwissLedgerColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(
          top: BorderSide(color: SwissLedgerColors.borderHairline, width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 12),
            // Type segmented control
            Container(
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
                    child: _TypeSegmentButton(
                      key: const Key('toggle_expense'),
                      label: 'Pengeluaran',
                      selected: _selectedType == 'expense',
                      activeColor: SwissLedgerColors.textPrimary,
                      onTap: () {
                        setState(() => _selectedType = 'expense');
                        _loadCategories();
                      },
                    ),
                  ),
                  Expanded(
                    child: _TypeSegmentButton(
                      key: const Key('toggle_income'),
                      label: 'Pemasukan',
                      selected: _selectedType == 'income',
                      activeColor: SwissLedgerColors.accentTeal,
                      onTap: () {
                        setState(() => _selectedType = 'income');
                        _loadCategories();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Nominal Display Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: SwissLedgerColors.bgPrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SwissLedgerColors.borderHairline,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Rp',
                        style: SwissLedgerTypography.monoTabular(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: SwissLedgerColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        key: const Key('quick_add_date_picker_button'),
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: SwissLedgerColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                PhosphorIconsRegular.calendarBlank,
                                size: 12,
                                color: SwissLedgerColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateIso,
                                style: SwissLedgerTypography.monoTabular(
                                  fontSize: 10,
                                  color: SwissLedgerColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    formattedDigits,
                    key: const Key('quick_add_amount_display'),
                    style: SwissLedgerTypography.monoTabular(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: SwissLedgerColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Category chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == _categories.length) {
                    return InkWell(
                      key: const Key('quick_add_new_category_chip'),
                      onTap: _showAddCategoryDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        decoration: BoxDecoration(
                          color: SwissLedgerColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: SwissLedgerColors.borderHairline,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              PhosphorIconsRegular.plus,
                              size: 13,
                              color: SwissLedgerColors.accentTeal,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Kategori',
                              style: SwissLedgerTypography.sans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: SwissLedgerColors.accentTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final cat = _categories[index];
                  final isSelected = cat.id == _selectedCategoryId;
                  return InkWell(
                    key: Key('category_chip_${cat.name}'),
                    onTap: () => setState(() => _selectedCategoryId = cat.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? SwissLedgerColors.textPrimary
                            : SwissLedgerColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? SwissLedgerColors.textPrimary
                              : SwissLedgerColors.borderHairline,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CategoryIconMapper.fromKey(cat.iconKey),
                            size: 14,
                            color: isSelected
                                ? Colors.white
                                : SwissLedgerColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat.name,
                            style: SwissLedgerTypography.sans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : SwissLedgerColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // Payment Method + Title row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedPaymentMethod,
                    isExpanded: true,
                    isDense: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      filled: true,
                      fillColor: SwissLedgerColors.bgPrimary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: SwissLedgerColors.borderHairline,
                        ),
                      ),
                    ),
                    style: SwissLedgerTypography.sans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SwissLedgerColors.textPrimary,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'QRIS / E-Wallet',
                        child: Text('QRIS / E-Wallet'),
                      ),
                      DropdownMenuItem(
                        value: 'Tunai',
                        child: Text('Tunai'),
                      ),
                      DropdownMenuItem(
                        value: 'Transfer Bank',
                        child: Text('Transfer Bank'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedPaymentMethod = val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: const Key('quick_add_title_field'),
                    controller: _titleController,
                    style: SwissLedgerTypography.sans(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Catatan singkat (opsional)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: SwissLedgerColors.bgPrimary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: SwissLedgerColors.borderHairline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Custom Tactile Integer Numpad
            _buildNumpadRow(['1', '2', '3']),
            const SizedBox(height: 6),
            _buildNumpadRow(['4', '5', '6']),
            const SizedBox(height: 6),
            _buildNumpadRow(['7', '8', '9']),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _NumpadKeyButton(
                    key: const Key('numpad_key_000'),
                    label: '.000',
                    subtle: true,
                    onTap: () => _appendDigits('000'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _NumpadKeyButton(
                    key: const Key('numpad_key_0'),
                    label: '0',
                    onTap: () => _appendDigits('0'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _NumpadKeyButton(
                    key: const Key('numpad_key_backspace'),
                    label: 'Hapus',
                    subtle: true,
                    icon: PhosphorIconsRegular.backspace,
                    onTap: _backspace,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                key: const Key('quick_add_submit_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwissLedgerColors.accentTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _amount > 0 ? _submitTransaction : null,
                child: Text(
                  'Simpan Transaksi',
                  style: SwissLedgerTypography.sans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpadRow(List<String> keys) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _NumpadKeyButton(
              key: Key('numpad_key_${keys[i]}'),
              label: keys[i],
              onTap: () => _appendDigits(keys[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _TypeSegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _TypeSegmentButton({
    super.key,
    required this.label,
    required this.selected,
    required this.activeColor,
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
          color: selected ? SwissLedgerColors.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: SwissLedgerTypography.sans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? activeColor : SwissLedgerColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _NumpadKeyButton extends StatelessWidget {
  final String label;
  final bool subtle;
  final IconData? icon;
  final VoidCallback onTap;

  const _NumpadKeyButton({
    super.key,
    required this.label,
    this.subtle = false,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: subtle
              ? SwissLedgerColors.surfaceSubtle
              : SwissLedgerColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: SwissLedgerColors.borderHairline,
            width: 1,
          ),
        ),
        child: icon != null
            ? Icon(icon, size: 18, color: SwissLedgerColors.textPrimary)
            : Text(
                label,
                style: SwissLedgerTypography.monoTabular(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SwissLedgerColors.textPrimary,
                ),
              ),
      ),
    );
  }
}
