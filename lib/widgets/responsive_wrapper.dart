// lib/widgets/responsive_wrapper.dart
// ─── Responsive Layout Wrapper ────────────────────────────────────────────────
// Adapts the layout between:
//   • Desktop/tablet web: centred card with max-width constraint
//   • Mobile/Telegram Mini App: full-width edge-to-edge with safe areas

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/form_provider.dart' as fp;

// ─── Breakpoints ──────────────────────────────────────────────────────────────

class FormBreakpoints {
  static const double mobile = 480;
  static const double tablet = 768;
  static const double desktop = 1024;
}

// ─── Layout mode ─────────────────────────────────────────────────────────────

enum FormLayoutMode { telegram, mobile, desktop }

FormLayoutMode _getLayoutMode(double width, bool isTelegram) {
  if (isTelegram || width < FormBreakpoints.mobile) {
    return FormLayoutMode.telegram;
  } else if (width < FormBreakpoints.tablet) {
    return FormLayoutMode.mobile;
  } else {
    return FormLayoutMode.desktop;
  }
}

// ─── Desktop Shell ─────────────────────────────────────────────────────────────

class _DesktopShell extends StatelessWidget {
  final Widget child;

  const _DesktopShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background gradient mesh
          Positioned.fill(
            child: CustomPaint(painter: _BackgroundPainter(theme: theme)),
          ),

          // Content
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    children: [
                      // Desktop top bar
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.dynamic_form_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Forms',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.desktop_windows_outlined,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Desktop',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Form content (fills its own scrollable list internally)
                      SizedBox(
                        height: MediaQuery.of(context).size.height - 180,
                        child: child,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Background Painter (desktop decoration) ──────────────────────────────────

class _BackgroundPainter extends CustomPainter {
  final ThemeData theme;

  _BackgroundPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = theme.colorScheme.primary;

    // Top-left orb
    final orb1 = Paint()
      ..color = baseColor.withOpacity(isDark ? 0.06 : 0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.15),
      200,
      orb1,
    );

    // Bottom-right orb
    final orb2 = Paint()
      ..color = baseColor.withOpacity(isDark ? 0.05 : 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.8),
      180,
      orb2,
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.theme != theme;
}

// ─── Telegram / Mobile Shell ──────────────────────────────────────────────────

class _TelegramShell extends StatelessWidget {
  final Widget child;
  final bool isTelegram;

  const _TelegramShell({required this.child, required this.isTelegram});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Telegram header safe area
      body: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            // Telegram-style top handle indicator (only in TMA)
            if (isTelegram)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),

            Expanded(child: child),

            // Bottom safe area padding for Telegram's bottom bar
            if (isTelegram)
              SizedBox(height: mediaQuery.padding.bottom > 0 ? 0 : 8),
          ],
        ),
      ),
    );
  }
}

// ─── RESPONSIVE WRAPPER ───────────────────────────────────────────────────────

/// Wraps any child in the correct shell for the current viewport and context.
/// Usage:
/// ```dart
/// ResponsiveFormWrapper(child: FormGenerator(schema: mySchema))
/// ```
class ResponsiveFormWrapper extends StatelessWidget {
  final Widget child;

  const ResponsiveFormWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isTelegram = context.watch<fp.FormProvider>().isTelegramContext;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mode = _getLayoutMode(constraints.maxWidth, isTelegram);

        switch (mode) {
          case FormLayoutMode.desktop:
            return _DesktopShell(child: child);
          case FormLayoutMode.mobile:
          case FormLayoutMode.telegram:
            return _TelegramShell(
              child: child,
              isTelegram: isTelegram,
            );
        }
      },
    );
  }
}

// ─── Responsive Value Helper ──────────────────────────────────────────────────
/// Returns a different value based on the current layout.
/// 
/// ```dart
/// double padding = responsiveValue(
///   context,
///   mobile: 16.0,
///   desktop: 32.0,
/// );
/// ```
T responsiveValue<T>(
  BuildContext context, {
  required T mobile,
  T? tablet,
  required T desktop,
}) {
  final width = MediaQuery.of(context).size.width;
  if (width >= FormBreakpoints.desktop) return desktop;
  if (width >= FormBreakpoints.tablet) return tablet ?? desktop;
  return mobile;
}
