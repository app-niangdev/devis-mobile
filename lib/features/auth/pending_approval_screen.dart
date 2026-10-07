import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import 'auth_scaffold.dart';

/// Fin de l'inscription : numéro confirmé, l'administrateur doit encore activer le compte.
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Demande envoyée',
      subtitle: 'Votre numéro est confirmé. L\'équipe SN Devis va vérifier votre inscription.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: AppColors.accentSoft, borderRadius: AppRadius.lgAll),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.mark_chat_read_outlined, color: AppColors.accent),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Vous recevrez un message WhatsApp dès l\'activation de votre compte. '
                    'Vous pourrez alors vous connecter avec votre numéro et votre mot de passe, '
                    'et profiter de votre période d\'essai gratuite.',
                    style: TextStyle(color: AppColors.textPrimary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/auth/login'),
            child: const Text('Retour à la connexion'),
          ),
        ],
      ),
    );
  }
}
