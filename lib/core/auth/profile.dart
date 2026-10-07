import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

Color parseHexColor(String? hex, Color fallback) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
    return fallback;
  }
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

String colorToHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Charte graphique de l'entreprise.
class Branding {
  const Branding({
    required this.name,
    this.slogan,
    this.logoUrl,
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  factory Branding.fromJson(Map<String, dynamic> json) => Branding(
        name: json['name'] as String? ?? '',
        slogan: json['slogan'] as String?,
        logoUrl: json['logo_url'] as String?,
        primary: parseHexColor(json['primary_color'] as String?, defaults.primary),
        secondary: parseHexColor(json['secondary_color'] as String?, defaults.secondary),
        accent: parseHexColor(json['accent_color'] as String?, defaults.accent),
      );

  /// Format de l'API, aussi utilisé pour mémoriser la charte sur le téléphone.
  Map<String, dynamic> toJson() => {
        'name': name,
        'slogan': slogan,
        'logo_url': logoUrl,
        'primary_color': colorToHex(primary),
        'secondary_color': colorToHex(secondary),
        'accent_color': colorToHex(accent),
      };

  @override
  bool operator ==(Object other) =>
      other is Branding &&
      other.name == name &&
      other.slogan == slogan &&
      other.logoUrl == logoUrl &&
      other.primary == primary &&
      other.secondary == secondary &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(name, slogan, logoUrl, primary, secondary, accent);

  /// Charte SN Devis : avant la première connexion, et pour une entreprise qui n'a pas choisi ses couleurs.
  static const defaults = Branding(
    name: 'SN Devis',
    primary: AppColors.accent,
    secondary: AppColors.darkSurface,
    accent: AppColors.highlight,
  );

  /// Aucune entreprise connue : on affiche l'identité SN Devis.
  bool get isPlatform => this == defaults;

  final String name;
  final String? slogan;
  final String? logoUrl;
  final Color primary;
  final Color secondary;
  final Color accent;
}

/// État d'abonnement : active | expiring | expired | none.
class SubscriptionStatus {
  const SubscriptionStatus({required this.state, this.plan, this.endsAt, this.daysLeft});

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) => SubscriptionStatus(
        state: json['state'] as String? ?? 'none',
        plan: json['plan'] as String?,
        endsAt: json['ends_at'] as String?,
        daysLeft: json['days_left'] as int?,
      );

  final String state;
  final String? plan;
  final String? endsAt;
  final int? daysLeft;

  bool get isExpiring => state == 'expiring';
}

class Profile {
  const Profile({
    required this.id,
    required this.firstName,
    required this.fullName,
    required this.phoneDisplay,
    this.phoneTwo,
    this.address,
    this.email,
    required this.role,
    required this.branding,
    this.subscription,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as int,
        firstName: json['first_name'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        phoneDisplay: (json['phone_display'] ?? json['phone'] ?? '') as String,
        phoneTwo: json['phone_two'] as String?,
        address: json['address'] as String?,
        email: json['email'] as String?,
        role: json['role'] as String? ?? '',
        branding: json['tenant'] is Map
            ? Branding.fromJson(Map<String, dynamic>.from(json['tenant'] as Map))
            : Branding.defaults,
        subscription: json['subscription'] is Map
            ? SubscriptionStatus.fromJson(Map<String, dynamic>.from(json['subscription'] as Map))
            : null,
      );

  final int id;
  final String firstName;
  final String fullName;
  final String phoneDisplay;
  final String? phoneTwo;
  final String? address;
  final String? email;
  final String role;
  final Branding branding;
  final SubscriptionStatus? subscription;
}
