import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/swiss_ledger_theme.dart';

/// Modern logo-only animated splash screen following Emil Kowalski's animation
/// principles (`animate` & `emil-design-eng`):
/// - Animates only GPU-friendly `transform` (`scale`, `translate`) and `opacity`.
/// - Never starts from `scale(0)` (`0.90 -> 1.0`).
/// - Uses strong custom ease-out `Cubic(0.23, 1.0, 0.32, 1.0)`.
/// - Respects `MediaQuery.maybeDisableAnimationsOf(context)`.
class AppSplashScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  final Duration duration;

  const AppSplashScreen({
    super.key,
    required this.onCompleted,
    this.duration = const Duration(milliseconds: 2400),
  });

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  static const Cubic _strongEaseOut = Cubic(0.23, 1.0, 0.32, 1.0);
  static const Cubic _strongEaseInOut = Cubic(0.77, 0.0, 0.175, 1.0);

  late final AnimationController _controller;
  late final Animation<double> _opacityAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _translateYAnim;
  late final Animation<double> _glowScaleAnim;
  late final Animation<double> _glowOpacityAnim;
  late final Animation<double> _sheenSlideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacityAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.08, 0.48, curve: _strongEaseOut),
    );
    _scaleAnim = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 0.56, curve: _strongEaseOut),
      ),
    );
    _translateYAnim = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 0.56, curve: _strongEaseOut),
      ),
    );
    _glowScaleAnim = Tween<double>(begin: 0.92, end: 1.22).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.14, 0.94, curve: _strongEaseOut),
      ),
    );
    _glowOpacityAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.38)
            .chain(CurveTween(curve: _strongEaseOut)),
        weight: 48,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.38, end: 0.16)
            .chain(CurveTween(curve: _strongEaseInOut)),
        weight: 52,
      ),
    ]).animate(_controller);
    _sheenSlideAnim = Tween<double>(begin: -1.4, end: 1.4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.34, 0.86, curve: _strongEaseInOut),
      ),
    );

    _controller.forward().whenComplete(() {
      if (mounted) {
        widget.onCompleted();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Scaffold(
      key: const Key('splash_screen_root'),
      backgroundColor: SwissLedgerColors.bgPrimary,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final opacity = _opacityAnim.value.clamp(0.0, 1.0);
            final scale = reduceMotion ? 1.0 : _scaleAnim.value;
            final offsetY = reduceMotion ? 0.0 : _translateYAnim.value;
            final glowScale = reduceMotion ? 1.0 : _glowScaleAnim.value;
            final glowOpacity = reduceMotion ? 0.16 : _glowOpacityAnim.value;
            final sheenOffset = _sheenSlideAnim.value;

            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, offsetY),
                child: Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width: 184,
                    height: 184,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Subtle ambient emerald halo (transform + opacity only)
                        Opacity(
                          opacity: glowOpacity.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: glowScale,
                            child: Container(
                              width: 136,
                              height: 136,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(36),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFF109F67),
                                    blurRadius: 36,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Crisp logo with subtle diagonal sheen sweep
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              child!,
                              if (!reduceMotion)
                                IgnorePointer(
                                  child: FractionalTranslation(
                                    translation: Offset(sheenOffset, 0),
                                    child: Transform.rotate(
                                      angle: -0.45,
                                      child: Container(
                                        width: 56,
                                        height: 180,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withValues(alpha: 0.0),
                                              Colors.white.withValues(alpha: 0.24),
                                              Colors.white.withValues(alpha: 0.0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          child: Image.asset(
            'assets/images/app_logo.png',
            key: const Key('splash_logo_image'),
            width: 124,
            height: 124,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
