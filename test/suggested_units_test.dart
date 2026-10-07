import 'package:devis_mobile/features/quotes/quote.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sans historique, les unités par défaut sont proposées', () {
    expect(suggestedUnits([]), defaultUnits);
  });

  test('les unités habituelles passent en tête, sans doublon de casse', () {
    final units = suggestedUnits([('Sac', 9), ('carreau', 4), ('rouleau', 1)]);

    expect(units.take(2), ['Sac', 'carreau']);
    expect(units, isNot(contains('sac')));
    // Une seule utilisation ne suffit pas à devenir une habitude
    expect(units, isNot(contains('rouleau')));
    expect(units, hasLength(12));
  });
}
