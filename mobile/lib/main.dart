import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/providers/app_providers.dart';
import 'package:personal_finance/app/shell/app_splash_screen.dart';
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
  static const Cubic _strongEaseOut = Cubic(0.23, 1.0, 0.32, 1.0);

  bool _restoring = true;
  bool _splashCompleted = false;

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

  void _onSplashCompleted() {
    if (mounted) {
      setState(() {
        _splashCompleted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.watch(authRepositoryProvider);
    final showSplash = _restoring || !_splashCompleted;

    return MaterialApp(
      title: 'Buku Kas Pribadi',
      debugShowCheckedModeBanner: false,
      theme: SwissLedgerTheme.light(),
      darkTheme: SwissLedgerTheme.dark(),
      themeMode: ThemeMode.light,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: _strongEaseOut,
        switchOutCurve: _strongEaseOut,
        transitionBuilder: (child, animation) {
          final scale = Tween<double>(begin: 0.98, end: 1.0).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: scale,
              child: child,
            ),
          );
        },
        child: showSplash
            ? AppSplashScreen(
                key: const ValueKey('app_splash_stage'),
                onCompleted: _onSplashCompleted,
              )
            : (authRepo.currentSession != null
                ? const MainShellScreen(key: ValueKey('main_shell_stage'))
                : const LoginScreen(key: ValueKey('login_screen_stage'))),
      ),
    );
  }
}
