import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/session.dart';
import '../../core/utils/phone.dart';
import '../../core/widgets/common.dart';
import '../../core/theme/app_colors.dart';

/// Profil du gestionnaire. Le numéro de connexion n'est modifiable que par l'administrateur.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _profile = context.read<Session>().profile;
  late final _phoneTwo = TextEditingController(text: _profile?.phoneTwo == null ? '' : formatPhone(_profile!.phoneTwo!));
  late final _address = TextEditingController(text: _profile?.address);
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_phoneTwo, _address, _current, _password, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final message = await context.read<Session>().updateProfile(
            phoneTwo: _phoneTwo.text.trim().isEmpty ? null : cleanPhone(_phoneTwo.text),
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
            currentPassword: _current.text,
            password: _password.text,
            confirmation: _confirmation.text,
          );
      if (mounted) {
        showMessage(context, message);
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        showMessage(context, e.message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Compte',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoRow('Nom', _profile?.fullName ?? ''),
                  InfoRow('Téléphone de connexion', _profile?.phoneDisplay ?? ''),
                  const SizedBox(height: 6),
                  Text('Pour changer de numéro, contactez l\'administrateur de la plateforme.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Coordonnées',
              child: Column(
                children: [
                  TextFormField(
                    controller: _phoneTwo,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [SenegalPhoneFormatter()],
                    decoration: const InputDecoration(labelText: 'Téléphone secondaire', hintText: '77 123 45 67'),
                    validator: (v) => validatePhone(v, required: false),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Changer le mot de passe',
              child: Column(
                children: [
                  TextFormField(
                    controller: _current,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
                    validator: (v) => _password.text.isNotEmpty && (v == null || v.isEmpty) ? 'Saisissez votre mot de passe actuel.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nouveau mot de passe', helperText: '8 caractères minimum'),
                    validator: (v) => (v != null && v.isNotEmpty && v.length < 8) ? '8 caractères minimum.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmation,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirmer le nouveau mot de passe'),
                    validator: (v) => _password.text.isNotEmpty && v != _password.text ? 'La confirmation ne correspond pas.' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const ButtonSpinner()
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
