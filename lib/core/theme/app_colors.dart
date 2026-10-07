import 'package:flutter/material.dart';

/// Palette officielle SN Devis, identique au frontend (frontend/src/styles/tokens.scss).
///
/// Règles d'usage du jaune ([highlight]) :
/// - jamais comme couleur de texte sur fond blanc (contraste insuffisant) ;
/// - tout texte posé sur du jaune utilise [highlightText] (anthracite) ;
/// - réservé aux accents : badge, indicateur actif, chiffre clé.
/// Le vert ([accent]) reste la couleur des actions principales : boutons, liens, focus, éléments actifs.
abstract final class AppColors {
  // Vert SN
  static const accent = Color(0xFF00853F);
  static const accentHover = Color(0xFF006B33); // état pressé, texte vert sur fond [accentSoft]
  static const accentSoft = Color(0xFFE6F3EC); // fond vert très clair

  // Jaune SN (accents uniquement)
  static const highlight = Color(0xFFFDEF42);
  static const highlightText = Color(0xFF17202A); // texte posé sur du jaune
  static const highlightSoft = Color(0xFFFFFCDD); // jaune à 18 % sur blanc

  // Surfaces
  static const pageBg = Color(0xFFF5F7F6);
  static const cardBg = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4E9ED);
  static const darkSurface = Color(0xFF17202A); // équivalent de la sidebar web

  // Texte
  static const textPrimary = Color(0xFF17202A);
  static const textSecondary = Color(0xFF5B6670);
  static const textMuted = Color(0xFF8A949E); // icônes et indices, pas de texte courant
  static const textInverse = Color(0xFFFFFFFF); // texte posé sur vert, anthracite ou danger

  // États
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const dangerHover = Color(0xFFB91C1C); // aussi : texte d'erreur sur [dangerSoft]
  static const dangerSoft = Color(0xFFFBE9E9); // danger à 10 % sur blanc
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFAEFE1); // avertissement à 12 % sur blanc

  /// Propre au mobile (absent du web) : devis envoyé, en attente de réponse.
  static const info = Color(0xFF2563EB);
}
