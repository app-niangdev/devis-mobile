import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';

/// Polices embarquées (assets/fonts) : aucun téléchargement au lancement.
abstract final class AppFonts {
  static const heading = 'Poppins';
  static const body = 'Inter';
}

/// Contraste WCAG entre deux couleurs (1 à 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// Texte lisible (blanc ou anthracite) posé sur [background] : sert aux couleurs
/// choisies par l'entreprise, dont on ne connaît pas la luminosité à l'avance.
Color readableOn(Color background) =>
    contrastRatio(AppColors.textInverse, background) >= contrastRatio(AppColors.textPrimary, background)
        ? AppColors.textInverse
        : AppColors.textPrimary;

/// Barre d'état à icônes sombres, pour les écrans à fond clair.
const darkStatusBar = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);

/// Thème de l'application, toujours aux couleurs SN Devis.
/// Les couleurs de chaque entreprise ne s'appliquent qu'à ses devis (PDF, aperçu).
final ThemeData appTheme = _buildTheme();

ThemeData _buildTheme() {
  // Schéma explicite : chaque rôle est fixé, aucune teinte dérivée d'une couleur source
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.accent,
    onPrimary: AppColors.textInverse,
    primaryContainer: AppColors.accentSoft,
    onPrimaryContainer: AppColors.textPrimary,
    // Le jaune n'est pas en « secondary » : Material 3 l'utiliserait pour des aplats (indicateurs, chips)
    secondary: AppColors.darkSurface,
    onSecondary: AppColors.textInverse,
    secondaryContainer: AppColors.accentSoft,
    onSecondaryContainer: AppColors.textPrimary,
    tertiary: AppColors.highlight,
    onTertiary: AppColors.highlightText,
    tertiaryContainer: AppColors.highlightSoft,
    onTertiaryContainer: AppColors.highlightText,
    error: AppColors.danger,
    onError: AppColors.textInverse,
    errorContainer: AppColors.dangerSoft,
    onErrorContainer: AppColors.dangerHover,
    surface: AppColors.cardBg,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceDim: AppColors.pageBg,
    surfaceBright: AppColors.cardBg,
    surfaceContainerLowest: AppColors.cardBg,
    surfaceContainerLow: AppColors.cardBg,
    surfaceContainer: AppColors.cardBg,
    surfaceContainerHigh: AppColors.pageBg,
    surfaceContainerHighest: AppColors.border,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    inverseSurface: AppColors.darkSurface,
    onInverseSurface: AppColors.textInverse,
    inversePrimary: AppColors.highlight,
    shadow: AppColors.textPrimary,
    scrim: AppColors.textPrimary,
    surfaceTint: Colors.transparent,
  );

  const border = OutlineInputBorder(
    borderRadius: AppRadius.mdAll,
    borderSide: BorderSide(color: AppColors.border),
  );

  // Titres en Poppins, texte courant en Inter (police par défaut)
  const heading = TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w600);
  final textTheme = TextTheme(
    displayLarge: heading.copyWith(fontWeight: FontWeight.w700),
    displayMedium: heading.copyWith(fontWeight: FontWeight.w700),
    displaySmall: heading.copyWith(fontWeight: FontWeight.w700),
    headlineLarge: heading,
    headlineMedium: heading,
    headlineSmall: heading,
    titleLarge: heading,
    titleMedium: heading,
    titleSmall: heading.copyWith(fontWeight: FontWeight.w500),
  ).apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);

  WidgetStateProperty<Color?> whenSelected(Color selected, [Color? otherwise]) =>
      WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? selected : otherwise);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    fontFamily: AppFonts.body,
    textTheme: textTheme,
    scaffoldBackgroundColor: AppColors.pageBg,
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cardBg,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: darkStatusBar,
      titleTextStyle: TextStyle(fontFamily: AppFonts.heading, fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardBg,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      errorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.danger)),
      focusedErrorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.error)
              ? AppColors.danger
              : states.contains(WidgetState.focused)
                  ? AppColors.accent
                  : AppColors.textSecondary,
        ),
      ),
      errorStyle: const TextStyle(color: AppColors.danger),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accent.withValues(alpha: 0.3),
      selectionHandleColor: AppColors.accent,
    ),
    filledButtonTheme: FilledButtonThemeData(style: _primaryButtonStyle),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _primaryButtonStyle.copyWith(elevation: const WidgetStatePropertyAll(0))),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size.fromHeight(48),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.accent),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardBg,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: AppColors.textPrimary.withValues(alpha: 0.12),
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: AppColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.cardBg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.accentSoft,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.accent : AppColors.textSecondary),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? AppColors.accentHover : AppColors.textSecondary,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.textInverse,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: whenSelected(AppColors.accentSoft, AppColors.cardBg),
        foregroundColor: whenSelected(AppColors.accentHover, AppColors.textPrimary),
        iconColor: whenSelected(AppColors.accentHover, AppColors.textSecondary),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.cardBg,
      selectedColor: AppColors.accentSoft,
      checkmarkColor: AppColors.accentHover,
      labelStyle: TextStyle(
        color: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.accentHover : AppColors.textPrimary),
      ),
      side: WidgetStateBorderSide.resolveWith(
        (s) => BorderSide(color: s.contains(WidgetState.selected) ? AppColors.accent : AppColors.border),
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: whenSelected(AppColors.textInverse),
      trackColor: whenSelected(AppColors.accent),
      trackOutlineColor: whenSelected(AppColors.accent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: whenSelected(AppColors.accent),
      checkColor: const WidgetStatePropertyAll(AppColors.textInverse),
    ),
    radioTheme: RadioThemeData(fillColor: whenSelected(AppColors.accent)),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accent),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.textSecondary),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.cardBg, surfaceTintColor: Colors.transparent),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.darkSurface,
      contentTextStyle: TextStyle(fontFamily: AppFonts.body, color: AppColors.textInverse),
      actionTextColor: AppColors.highlight,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
    ),
  );
}

/// Boutons pleins : vert, texte blanc, vert foncé à l'appui.
final ButtonStyle _primaryButtonStyle = FilledButton.styleFrom(
  foregroundColor: AppColors.textInverse,
  minimumSize: const Size.fromHeight(50),
  shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
  textStyle: const TextStyle(fontFamily: AppFonts.body, fontSize: 16, fontWeight: FontWeight.w600),
).copyWith(
  backgroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.disabled)
        ? AppColors.textPrimary.withValues(alpha: 0.12)
        : s.contains(WidgetState.pressed)
            ? AppColors.accentHover
            : AppColors.accent,
  ),
  foregroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.disabled) ? AppColors.textPrimary.withValues(alpha: 0.38) : AppColors.textInverse,
  ),
);
