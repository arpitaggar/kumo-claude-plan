import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/brand.dart';
import '../../../../config/theme_provider.dart';
import '../../../../shared/extensions/context_extensions.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _taglineSlide;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _titleOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0, 0.45, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, -0.35), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
          ),
        );

    _logoOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 0.6, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.78, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.15, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _taglineOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
    );
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
          ),
        );

    _ctrl.forward().then((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoSvg = Brand.logoFor(ref.watch(themeProvider));

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _titleOpacity,
              child: SlideTransition(
                position: _titleSlide,
                child: Text(
                  Brand.appName,
                  style: TextStyle(
                    fontFamily: Brand.fontFamily,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.onSurface,
                    letterSpacing: 6,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            FadeTransition(
              opacity: _logoOpacity,
              child: ScaleTransition(
                scale: _logoScale,
                child: SvgPicture.asset(logoSvg, width: 130),
              ),
            ),

            const SizedBox(height: 20),

            FadeTransition(
              opacity: _taglineOpacity,
              child: SlideTransition(
                position: _taglineSlide,
                child: Text(
                  Brand.tagline,
                  style: TextStyle(
                    fontFamily: Brand.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: context.colorScheme.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
