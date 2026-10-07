import 'package:flutter/material.dart';

import '../auth/profile.dart';
import '../widgets/sn_brand.dart';

/// Contraste WCAG entre deux couleurs (1 à 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// Texte lisible (blanc ou presque noir) posé sur [background].
Color readableOn(Color background) =>
    contrastRatio(Colors.white, background) >= contrastRatio(_ink, background) ? Colors.white : _ink;

/// Assombrit [color] jusqu'à atteindre [minRatio] sur [background] :
/// une couleur claire (jaune, cyan…) reste utilisable pour du texte ou des icônes.
Color legibleOn(Color color, Color background, {double minRatio = 4.5}) {
  var hsl = HSLColor.fromColor(color);
  while (contrastRatio(hsl.toColor(), background) < minRatio && hsl.lightness > 0.05) {
    hsl = hsl.withLightness((hsl.lightness - 0.04).clamp(0.0, 1.0));
  }
  return hsl.toColor();
}

const _ink = SnColors.ink;
const _surface = Colors.white;

/// Les 3 couleurs de l'entreprise et leurs variantes lisibles, accessibles via
/// `Theme.of(context).extension<BrandColors>()!` ou `context.brand`.
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryInk,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryInk,
    required this.accent,
    required this.onAccent,
    required this.accentInk,
  });

  factory BrandColors.from(Branding b) => BrandColors(
        primary: b.primary,
        onPrimary: readableOn(b.primary),
        primaryInk: legibleOn(b.primary, _surface),
        secondary: b.secondary,
        onSecondary: readableOn(b.secondary),
        secondaryInk: legibleOn(b.secondary, _surface),
        accent: b.accent,
        onAccent: readableOn(b.accent),
        accentInk: legibleOn(b.accent, _surface),
      );

  /// Fond des boutons et éléments actifs.
  final Color primary;
  final Color onPrimary;

  /// Variante de [primary] pour du texte ou des icônes sur fond blanc.
  final Color primaryInk;

  /// En-têtes et blocs de structure.
  final Color secondary;
  final Color onSecondary;
  final Color secondaryInk;

  /// Mise en avant : action principale, badges.
  final Color accent;
  final Color onAccent;
  final Color accentInk;

  @override
  BrandColors copyWith() => this;

  @override
  BrandColors lerp(BrandColors? other, double t) {
    if (other == null) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return BrandColors(
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primaryInk: mix(primaryInk, other.primaryInk),
      secondary: mix(secondary, other.secondary),
      onSecondary: mix(onSecondary, other.onSecondary),
      secondaryInk: mix(secondaryInk, other.secondaryInk),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      accentInk: mix(accentInk, other.accentInk),
    );
  }
}

extension BrandContext on BuildContext {
  BrandColors get brand => Theme.of(this).extension<BrandColors>()!;
}

/// Thème construit à partir des 3 couleurs de l'entreprise :
/// principale = actions, secondaire = structure (en-têtes), accent = mise en avant.
ThemeData buildTheme(Branding branding) {
  final brand = BrandColors.from(branding);

  final scheme = ColorScheme.fromSeed(seedColor: branding.primary).copyWith(
    primary: brand.primary,
    onPrimary: brand.onPrimary,
    primaryContainer: Color.alphaBlend(brand.primary.withValues(alpha: 0.12), _surface),
    onPrimaryContainer: brand.primaryInk,
    secondary: brand.secondary,
    onSecondary: brand.onSecondary,
    secondaryContainer: Color.alphaBlend(brand.secondary.withValues(alpha: 0.10), _surface),
    onSecondaryContainer: brand.secondaryInk,
    tertiary: brand.accent,
    onTertiary: brand.onAccent,
    tertiaryContainer: Color.alphaBlend(brand.accent.withValues(alpha: 0.18), _surface),
    onTertiaryContainer: brand.accentInk,
    surface: _surface,
    onSurface: _ink,
    surfaceTint: Colors.transparent,
  );

  // Fond général très légèrement teinté par la couleur principale
  final background = Color.alphaBlend(brand.primary.withValues(alpha: 0.035), SnColors.pageBg);

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [brand],
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: brand.secondary,
      foregroundColor: brand.onSecondary,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: brand.primaryInk, width: 1.6)),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(color: states.contains(WidgetState.error) ? scheme.error : brand.primaryInk),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: brand.primaryInk,
      selectionColor: brand.primary.withValues(alpha: 0.3),
      selectionHandleColor: brand.primaryInk,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brand.primary,
        foregroundColor: brand.onPrimary,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brand.primaryInk,
        side: BorderSide(color: brand.primaryInk.withValues(alpha: 0.5)),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: brand.primaryInk),
    ),
    cardTheme: CardThemeData(
      color: _surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: brand.primary.withValues(alpha: 0.16),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? brand.primaryInk : Colors.grey.shade600),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? brand.primaryInk : Colors.grey.shade700,
        ),
      ),
    ),
    // L'action principale (« Nouveau devis ») ressort avec la couleur d'accent
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: brand.accent,
      foregroundColor: brand.onAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? brand.primary : _surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? brand.onPrimary : _ink,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? brand.onPrimary : _ink,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: brand.primary,
      secondarySelectedColor: brand.primary,
      checkmarkColor: brand.onPrimary,
      labelStyle: const TextStyle(color: _ink),
      secondaryLabelStyle: TextStyle(color: brand.onPrimary),
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? brand.onPrimary : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? brand.primary : null),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? brand.primary : null),
      checkColor: WidgetStatePropertyAll(brand.onPrimary),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? brand.primaryInk : null),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: brand.primaryInk),
    listTileTheme: ListTileThemeData(iconColor: brand.secondaryInk),
    dialogTheme: const DialogThemeData(backgroundColor: _surface, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: _surface, surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: brand.secondary,
      contentTextStyle: TextStyle(color: brand.onSecondary),
      actionTextColor: brand.onSecondary,
    ),
  );
}
