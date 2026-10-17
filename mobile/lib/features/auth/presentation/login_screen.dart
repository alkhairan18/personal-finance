import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/providers/app_providers.dart';
import 'package:personal_finance/app/theme/swiss_ledger_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController(text: 'anzhel');
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController(text: 'http://10.0.2.2:8000');
  bool _showServerSettings = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).login(
            username: _usernameController.text,
            password: _passwordController.text,
            serverUrl: _serverUrlController.text,
          );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst(RegExp(r'^.*Exception:\s*'), '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeUsername = _usernameController.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: SwissLedgerColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: SwissLedgerColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: SwissLedgerColors.borderHairline,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: SwissLedgerColors.accentTealSubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            PhosphorIconsRegular.bookBookmark,
                            size: 18,
                            color: SwissLedgerColors.accentTeal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BUKU KAS PRIBADI',
                                style: SwissLedgerTypography.sans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: SwissLedgerColors.textMuted,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Masuk ke Akun Terisolasi',
                                style: SwissLedgerTypography.sans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: SwissLedgerColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'PILIH AKUN',
                      style: SwissLedgerTypography.sans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SwissLedgerColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _AccountSelectorButton(
                            label: 'Anzhel',
                            selected: activeUsername == 'anzhel',
                            onTap: () {
                              setState(() {
                                _usernameController.text = 'anzhel';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AccountSelectorButton(
                            label: 'Wina',
                            selected: activeUsername == 'wina',
                            onTap: () {
                              setState(() {
                                _usernameController.text = 'wina';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('login_username_field'),
                      controller: _usernameController,
                      onChanged: (_) => setState(() {}),
                      style: SwissLedgerTypography.sans(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        isDense: true,
                        filled: true,
                        fillColor: SwissLedgerColors.bgPrimary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: SwissLedgerColors.borderHairline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('login_password_field'),
                      controller: _passwordController,
                      obscureText: true,
                      style: SwissLedgerTypography.sans(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Kata Sandi',
                        hintText: 'Minimal 8 karakter',
                        isDense: true,
                        filled: true,
                        fillColor: SwissLedgerColors.bgPrimary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: SwissLedgerColors.borderHairline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showServerSettings = !_showServerSettings;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              PhosphorIconsRegular.slidersHorizontal,
                              size: 15,
                              color: SwissLedgerColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Pengaturan URL Server Sinkronisasi',
                              style: SwissLedgerTypography.sans(
                                fontSize: 12,
                                color: SwissLedgerColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showServerSettings) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _serverUrlController,
                        style: SwissLedgerTypography.monoTabular(fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'URL API Server',
                          isDense: true,
                          filled: true,
                          fillColor: SwissLedgerColors.bgPrimary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: SwissLedgerColors.borderHairline,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: SwissLedgerColors.dangerSubtle,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: SwissLedgerTypography.sans(
                            fontSize: 12,
                            color: SwissLedgerColors.dangerRed,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        key: const Key('login_submit_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SwissLedgerColors.accentTeal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _submitLogin,
                        child: Text(
                          _isSubmitting ? 'Memproses...' : 'Buka Buku Kas',
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
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountSelectorButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AccountSelectorButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? SwissLedgerColors.accentTealSubtle
              : SwissLedgerColors.bgPrimary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? SwissLedgerColors.accentTeal
                : SwissLedgerColors.borderHairline,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.userCircle,
              size: 16,
              color: selected
                  ? SwissLedgerColors.accentTeal
                  : SwissLedgerColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: SwissLedgerTypography.sans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected
                    ? SwissLedgerColors.accentTeal
                    : SwissLedgerColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
