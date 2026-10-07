import 'package:devis_mobile/features/company/company.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chaque période donne ses paramètres et son libellé', () {
    expect(const DashboardPeriod().toQuery(), isEmpty);
    expect(const DashboardPeriod().label, 'depuis le début');

    expect(const DashboardPeriod(year: 2025).toQuery(), {'year': 2025});
    expect(const DashboardPeriod(year: 2025).label, 'en 2025');

    expect(const DashboardPeriod(year: 2026, month: 10).toQuery(), {'year': 2026, 'month': 10});
    expect(const DashboardPeriod(year: 2026, month: 10).label, 'en octobre 2026');

    final day = DashboardPeriod(date: DateTime(2026, 3, 7));
    expect(day.toQuery(), {'date': '2026-03-07'});
    expect(day.label, 'le 07/03/2026');
  });
}
