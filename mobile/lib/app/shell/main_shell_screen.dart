import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/providers/app_providers.dart';
import 'package:personal_finance/app/theme/swiss_ledger_theme.dart';
import 'package:personal_finance/features/dashboard/presentation/buku_kas_screen.dart';
import 'package:personal_finance/features/debts/presentation/kewajiban_screen.dart';
import 'package:personal_finance/features/reports/presentation/reports_and_more_screen.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add_transaction_sheet.dart';
import 'package:personal_finance/features/wishlist/presentation/wishlist_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  final Widget? kewajibanTab;
  final Widget? wishlistTab;
  final Widget? laporanTab;
  final bool? enableAutoSync;

  const MainShellScreen({
    super.key,
    this.kewajibanTab,
    this.wishlistTab,
    this.laporanTab,
    this.enableAutoSync,
  });

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with WidgetsBindingObserver {
  bool get _shouldAutoSync =>
      widget.enableAutoSync ??
      !WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_shouldAutoSync) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _triggerSync(silent: true);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _shouldAutoSync && mounted) {
      _triggerSync(silent: true);
    }
  }
  int _selectedIndex = 0;

  Future<void> _openQuickAddSheet() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickAddTransactionSheet(),
    );
  }

  Future<void> _triggerSync({bool silent = false}) async {
    if (ref.read(isSyncingProvider)) return;
    final syncEngine = ref.read(syncEngineProvider);
    if (syncEngine == null) return;
    ref.read(isSyncingProvider.notifier).state = true;
    try {
      final result = await syncEngine.synchronize();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        if (result.success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Sinkronisasi selesai (${result.pushedCount} terkirim, ${result.pulledCount} diterima)',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (!silent) {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: SwissLedgerColors.dangerRed,
              content: Text(
                'Sinkronisasi belum berhasil: ${result.errorMessage ?? 'Periksa koneksi server'}',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        ref.read(isSyncingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.watch(authRepositoryProvider);
    final db = ref.watch(activeDatabaseProvider);
    final isSyncing = ref.watch(isSyncingProvider);
    final session = authRepo.currentSession;

    final tabs = <Widget>[
      const BukuKasScreen(),
      widget.kewajibanTab ?? const KewajibanScreen(),
      widget.wishlistTab ?? const WishlistScreen(),
      widget.laporanTab ?? const ReportsAndMoreScreen(),
    ];

    return Scaffold(
      backgroundColor: SwissLedgerColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: Container(
          decoration: const BoxDecoration(
            color: SwissLedgerColors.surfaceElevated,
            border: Border(
              bottom: BorderSide(
                color: SwissLedgerColors.borderHairline,
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: SwissLedgerColors.accentTeal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        session?.displayName ?? 'Pengguna',
                        style: SwissLedgerTypography.sans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SwissLedgerColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (db != null)
                    FutureBuilder<int>(
                      future: db.getPendingOutboxCount(),
                      builder: (context, snapshot) {
                        final pendingCount = snapshot.data ?? 0;
                        final hasPending = pendingCount > 0;
                        return InkWell(
                          key: const Key('header_sync_status_badge'),
                          onTap: isSyncing ? null : _triggerSync,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: hasPending
                                  ? SwissLedgerColors.warningSubtle
                                  : SwissLedgerColors.accentTealSubtle,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isSyncing
                                  ? 'Menyinkronkan...'
                                  : (hasPending
                                      ? 'Offline · $pendingCount antrean'
                                      : 'Tersinkron'),
                              style: SwissLedgerTypography.monoTabular(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: hasPending
                                    ? SwissLedgerColors.warningAmber
                                    : SwissLedgerColors.accentTeal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: tabs[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: SwissLedgerColors.surfaceElevated,
          border: Border(
            top: BorderSide(color: SwissLedgerColors.borderHairline, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _BottomNavItem(
                    key: const Key('nav_tab_buku_kas'),
                    icon: PhosphorIconsRegular.bookOpenText,
                    label: 'Buku Kas',
                    selected: _selectedIndex == 0,
                    onTap: () => setState(() => _selectedIndex = 0),
                  ),
                ),
                Expanded(
                  child: _BottomNavItem(
                    key: const Key('nav_tab_kewajiban'),
                    icon: PhosphorIconsRegular.scales,
                    label: 'Kewajiban',
                    selected: _selectedIndex == 1,
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                ),
                InkWell(
                  key: const Key('nav_quick_add_button'),
                  onTap: _openQuickAddSheet,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: SwissLedgerColors.accentTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          PhosphorIconsRegular.plus,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Catat',
                          style: SwissLedgerTypography.sans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _BottomNavItem(
                    key: const Key('nav_tab_wishlist'),
                    icon: PhosphorIconsRegular.bookmarkSimple,
                    label: 'Wishlist',
                    selected: _selectedIndex == 2,
                    onTap: () => setState(() => _selectedIndex = 2),
                  ),
                ),
                Expanded(
                  child: _BottomNavItem(
                    key: const Key('nav_tab_laporan'),
                    icon: PhosphorIconsRegular.filePdf,
                    label: 'Laporan',
                    selected: _selectedIndex == 3,
                    onTap: () => setState(() => _selectedIndex = 3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? SwissLedgerColors.accentTeal
        : SwissLedgerColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: SwissLedgerTypography.sans(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
