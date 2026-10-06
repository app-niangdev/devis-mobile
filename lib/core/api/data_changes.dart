import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Signal émis après chaque écriture réussie sur l'API (création, modification,
/// suppression, action) : les écrans abonnés rechargent leurs données.
class DataChanges extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Recharge l'écran à chaque [DataChanges], même s'il est caché (onglet, page en dessous).
mixin ReloadOnDataChange<T extends StatefulWidget> on State<T> {
  late final DataChanges _changes;

  /// Recharge silencieuse : garder les données affichées pendant le chargement.
  void onDataChanged();

  void _handleChange() {
    if (mounted) {
      onDataChanged();
    }
  }

  @override
  void initState() {
    super.initState();
    _changes = context.read<DataChanges>()..addListener(_handleChange);
  }

  @override
  void dispose() {
    _changes.removeListener(_handleChange);
    super.dispose();
  }
}
