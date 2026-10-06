import 'package:devis_mobile/core/update/app_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compareVersions compare chaque segment numériquement', () {
    expect(compareVersions('1.0.0', '1.0.1'), -1);
    expect(compareVersions('1.10.0', '1.9.0'), 1);
    expect(compareVersions('2.0', '2.0.0'), 0);
    expect(compareVersions('1.2.0+7', '1.2.0'), 0);
  });
}
