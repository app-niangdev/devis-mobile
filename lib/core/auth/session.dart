import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/token_store.dart';
import '../theme/branding_store.dart';
import 'profile.dart';

enum SessionStatus { loading, signedOut, signedIn }

/// Étape renvoyée par les parcours de connexion :
/// `authenticated`, `otp_required` (code WhatsApp) ou `set_password`.
class AuthStep {
  AuthStep.fromJson(Map<String, dynamic> json)
      : step = json['step'] as String? ?? '',
        purpose = json['purpose'] as String?,
        challengeToken = json['challenge_token'] as String?,
        phoneMasked = json['phone_masked'] as String?,
        resetToken = json['reset_token'] as String?,
        expiresIn = json['expires_in'] as int? ?? 0,
        resendIn = json['resend_in'] as int? ?? 0,
        resendsLeft = json['resends_left'] as int? ?? 0;

  final String step;
  final String? purpose;
  final String? challengeToken;
  final String? phoneMasked;
  final String? resetToken;
  final int expiresIn;
  final int resendIn;
  final int resendsLeft;

  bool get isAuthenticated => step == 'authenticated';
  bool get needsOtp => step == 'otp_required';
  bool get needsPassword => step == 'set_password';
}

/// Session du gestionnaire : jetons, profil et charte de son entreprise.
class Session extends ChangeNotifier {
  Session(this.api) {
    api.onSessionEnded = (reason) => signOut(message: reason.message, code: reason.code);
  }

  final ApiClient api;
  TokenStore get _tokens => api.tokens;

  final BrandingStore _brandingStore = BrandingStore();

  SessionStatus status = SessionStatus.loading;
  Profile? profile;

  /// Dernière charte connue sur ce téléphone, utilisée tant que le profil n'est pas chargé.
  Branding? _lastBranding;

  /// Charte de l'entreprise (logo, nom, couleurs de ses devis), sinon celle de SN Devis.
  Branding get branding => profile?.branding ?? _lastBranding ?? Branding.defaults;

  /// Motif de la dernière déconnexion forcée (abonnement expiré…), affiché à l'écran de connexion.
  String? endedMessage;

  /// Code de cette déconnexion (`SUBSCRIPTION_EXPIRED` : l'écran de connexion affiche les forfaits).
  String? endedCode;

  Future<void> init() async {
    _lastBranding = await _brandingStore.load();
    if (_lastBranding != null) {
      notifyListeners();
    }
    await _tokens.load();
    if (!_tokens.hasTokens) {
      _setStatus(SessionStatus.signedOut);
      return;
    }
    try {
      await refreshProfile();
      _setStatus(SessionStatus.signedIn);
    } on ApiException catch (e) {
      // Hors connexion au démarrage : on garde la session, les écrans afficheront l'erreur
      if (e.code == 'NETWORK') {
        _setStatus(SessionStatus.signedIn);
      } else {
        final blocking = blockingCodes.contains(e.code);
        await signOut(message: blocking ? e.message : null, code: blocking ? e.code : null);
      }
    }
  }

  Future<AuthStep> login(String phone, String password) async {
    endedMessage = null;
    endedCode = null;
    final body = await api.postPublic('/auth/login', {'phone': phone, 'password': password});
    return _handleStep(body);
  }

  Future<AuthStep> verifyOtp(String challengeToken, String code) async {
    final body = await api.postPublic('/auth/otp/verify', {'challenge_token': challengeToken, 'code': code});
    return _handleStep(body);
  }

  Future<AuthStep> resendOtp(String challengeToken) async {
    final body = await api.postPublic('/auth/otp/resend', {'challenge_token': challengeToken});
    return AuthStep.fromJson(Map<String, dynamic>.from(body['payload'] as Map));
  }

  Future<AuthStep> forgotPassword(String phone) async {
    final body = await api.postPublic('/auth/forgot-password', {'phone': phone});
    return AuthStep.fromJson(Map<String, dynamic>.from(body['payload'] as Map));
  }

  /// Nouveau mot de passe après le code (première connexion ou mot de passe oublié).
  Future<AuthStep> setPassword(String resetToken, String password, String confirmation) async {
    final body = await api.postPublic('/auth/password/set', {
      'reset_token': resetToken,
      'password': password,
      'password_confirmation': confirmation,
    });
    return _handleStep(body);
  }

  Future<void> refreshProfile() async {
    final body = await api.get('/auth/me');
    _setProfile(Profile.fromJson(Map<String, dynamic>.from(body['payload'] as Map)));
    notifyListeners();
  }

  Future<String> updateProfile({String? phoneTwo, String? address, String? currentPassword, String? password, String? confirmation}) async {
    final body = await api.put('/auth/me', {
      'phone_two': phoneTwo,
      'address': address,
      if (password != null && password.isNotEmpty) ...{
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': confirmation,
      },
    });
    _setProfile(Profile.fromJson(Map<String, dynamic>.from(body['payload'] as Map)));
    notifyListeners();
    return body['message'] as String? ?? 'Profil mis à jour.';
  }

  Future<void> signOut({String? message, String? code}) async {
    if (status == SessionStatus.signedIn) {
      try {
        await api.post('/auth/logout');
      } catch (_) {
        // Jetons sans état : la suppression locale suffit
      }
    }
    await _tokens.clear();
    profile = null;
    endedMessage = message;
    endedCode = code;
    _setStatus(SessionStatus.signedOut);
  }

  Future<AuthStep> _handleStep(Map<String, dynamic> body) async {
    final payload = Map<String, dynamic>.from(body['payload'] as Map);
    final step = AuthStep.fromJson(payload);

    if (step.isAuthenticated) {
      final user = Profile.fromJson(Map<String, dynamic>.from(payload['user'] as Map));
      if (user.role != 'MANAGER') {
        throw ApiException('Cette application est réservée aux gestionnaires d\'entreprise.', code: 'FORBIDDEN');
      }
      await _tokens.save(payload['access_token'] as String, payload['refresh_token'] as String);
      _setProfile(user);
      _setStatus(SessionStatus.signedIn);
    }

    return step;
  }

  void _setProfile(Profile value) {
    profile = value;
    if (value.branding != _lastBranding) {
      _lastBranding = value.branding;
      _brandingStore.save(value.branding);
    }
  }

  void _setStatus(SessionStatus value) {
    status = value;
    notifyListeners();
  }
}
