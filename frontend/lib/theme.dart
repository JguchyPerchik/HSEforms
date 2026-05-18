import 'package:flutter/material.dart';

class HseColors {
  static const primary = Color(0xFF0F2D69);
  static const primaryBright = Color(0xFF234B9B);
  static const secondary = Color(0xFF234B9B);
  static const accent = Color(0xFF5A7BD6);
  static const muted = Color(0xFF929292);
  static const border = Color(0xFFE6E6E6);
  static const borderStrong = Color(0xFFC6C6C6);
  static const surface = Color(0xFFF5F6FA);
  static const surfaceAlt = Color(0xFFEEF1F8);
  static const background = Color(0xFFFCFCFE);
  static const ink = Color(0xFF14182B);
  static const inkSoft = Color(0xFF4A4F66);
  static const danger = Color(0xFFE05656);
  static const success = Color(0xFF2E9D6E);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryBright],
  );
}

class HseRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

class HseShadows {
  static const card = [
    BoxShadow(color: Color(0x0A14182B), blurRadius: 20, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x05000000), blurRadius: 1, offset: Offset(0, 1)),
  ];
  static const lift = [
    BoxShadow(color: Color(0x1A14182B), blurRadius: 32, offset: Offset(0, 12)),
  ];
}

const String _bodyFont = 'HSESans';
const String _displayFont = 'HSESans';

ThemeData buildHseTheme() {
  final scheme = const ColorScheme(
    brightness: Brightness.light,
    primary: HseColors.primary,
    onPrimary: Colors.white,
    secondary: HseColors.primaryBright,
    onSecondary: Colors.white,
    surface: HseColors.background,
    onSurface: HseColors.ink,
    surfaceContainerHighest: HseColors.surface,
    surfaceContainer: HseColors.surfaceAlt,
    outline: HseColors.border,
    outlineVariant: HseColors.border,
    error: HseColors.danger,
    onError: Colors.white,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _bodyFont,
    scaffoldBackgroundColor: HseColors.background,
    splashFactory: InkSparkle.splashFactory,
  );

  final textTheme = base.textTheme.copyWith(
    displayLarge: const TextStyle(
        fontFamily: _displayFont,
        fontSize: 44,
        fontWeight: FontWeight.w600,
        height: 1.05,
        color: HseColors.ink,
        letterSpacing: -0.5),
    displayMedium: const TextStyle(
        fontFamily: _displayFont,
        fontSize: 34,
        fontWeight: FontWeight.w600,
        height: 1.1,
        color: HseColors.ink,
        letterSpacing: -0.3),
    headlineLarge: const TextStyle(
        fontFamily: _displayFont,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: HseColors.ink),
    headlineMedium: const TextStyle(
        fontFamily: _displayFont,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: HseColors.ink),
    headlineSmall: const TextStyle(
        fontFamily: _bodyFont,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: HseColors.ink),
    titleLarge: const TextStyle(
        fontFamily: _bodyFont,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: HseColors.ink),
    titleMedium: const TextStyle(
        fontFamily: _bodyFont,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: HseColors.ink),
    bodyLarge: const TextStyle(
        fontFamily: _bodyFont,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: HseColors.ink),
    bodyMedium: const TextStyle(
        fontFamily: _bodyFont,
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: HseColors.inkSoft),
    bodySmall: const TextStyle(
        fontFamily: _bodyFont,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: HseColors.muted),
    labelLarge: const TextStyle(
        fontFamily: _bodyFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1),
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: HseColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 68,
      titleTextStyle: TextStyle(
          fontFamily: _displayFont,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: HseColors.ink),
      iconTheme: IconThemeData(color: HseColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HseColors.surface,
      hintStyle:
          const TextStyle(fontFamily: _displayFont, color: HseColors.muted),
      labelStyle: const TextStyle(
          color: HseColors.inkSoft, fontWeight: FontWeight.w500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HseRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HseRadius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HseRadius.md),
        borderSide: const BorderSide(color: HseColors.primaryBright, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HseRadius.md),
        borderSide: const BorderSide(color: HseColors.danger, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x0A14182B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HseRadius.lg),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HseColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: HseColors.borderStrong,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HseRadius.md)),
        textStyle: const TextStyle(
            fontFamily: _bodyFont,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.1),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: HseColors.primary,
        backgroundColor: Colors.white,
        side: const BorderSide(color: HseColors.borderStrong, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HseRadius.md)),
        textStyle: const TextStyle(
            fontFamily: _bodyFont, fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: HseColors.primaryBright,
        textStyle: const TextStyle(
            fontFamily: _displayFont, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HseRadius.sm)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: HseColors.inkSoft,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HseRadius.sm)),
      ),
    ),
    dividerTheme:
        const DividerThemeData(color: HseColors.border, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: HseColors.surface,
      selectedColor: HseColors.primary,
      labelStyle: const TextStyle(
          fontFamily: _displayFont,
          color: HseColors.ink,
          fontWeight: FontWeight.w600,
          fontSize: 13.5),
      secondaryLabelStyle: const TextStyle(
          fontFamily: _displayFont,
          color: Colors.white,
          fontWeight: FontWeight.w600),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HseRadius.md)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: HseColors.ink,
      contentTextStyle: const TextStyle(
          fontFamily: _displayFont,
          color: Colors.white,
          fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HseRadius.md)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HseRadius.lg)),
      titleTextStyle: const TextStyle(
          fontFamily: _displayFont,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: HseColors.ink),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: HseColors.primary,
      foregroundColor: Colors.white,
      elevation: 6,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? HseColors.primary
              : HseColors.borderStrong),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}

class GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsets padding;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.child,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(HseRadius.md),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            gradient: HseColors.gradient,
            borderRadius: BorderRadius.circular(HseRadius.md),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x3315306B),
                  blurRadius: 16,
                  offset: Offset(0, 6)),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: padding,
              child: Center(
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                      fontFamily: _displayFont,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      height: 1,
                      letterSpacing: 0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 18),
                        const SizedBox(width: 8)
                      ],
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft-shadow card without border.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  const SoftCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20),
      this.color,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(HseRadius.lg),
        boxShadow: HseShadows.card,
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(HseRadius.lg),
        onTap: onTap,
        child: body,
      ),
    );
  }
}
