import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/providers/app_providers.dart';
import 'package:personal_finance/app/shell/main_shell_screen.dart';
import 'package:personal_finance/app/theme/swiss_ledger_theme.dart';
import 'package:personal_finance/features/auth/presentation/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PersonalFinanceApp()));
}

class PersonalFinanceApp extends ConsumerStatefulWidget {
  const PersonalFinanceApp({super.key});

  @override
  ConsumerState<PersonalFinanceApp> createState() => _PersonalFinanceAppState();
}

class _PersonalFinanceAppState extends ConsumerState<PersonalFinanceApp> {
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await ref.read(authRepositoryProvider).restoreSession();
    if (mounted) {
      setState(() {
        _restoring = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.watch(authRepositoryProvider);

    return MaterialApp(
      title: 'Buku Kas Pribadi',
      debugShowCheckedModeBanner: false,
      theme: SwissLedgerTheme.light(),
      darkTheme: SwissLedgerTheme.dark(),
      themeMode: ThemeMode.system,
      home: _restoring
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : (authRepo.currentSession != null
              ? const MainShellScreen()
              : const LoginScreen()),
    );
  }
}
