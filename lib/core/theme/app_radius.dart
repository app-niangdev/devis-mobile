import 'package:flutter/widgets.dart';

/// Rayons d'arrondi SN Devis, identiques au frontend.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;
  static const double pill = 999;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}
