import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';

/// Informations de l'entreprise modifiables par le gestionnaire.
class Company {
  Company.fromJson(Map<String, dynamic> json) : data = json;

  final Map<String, dynamic> data;

  String text(String key) => data[key] as String? ?? '';
  int number(String key, [int fallback = 0]) => (data[key] as num?)?.toInt() ?? fallback;
}

class CompanyRepository {
  CompanyRepository(this.api);

  final ApiClient api;

  Future<Company> get() async {
    final body = await api.get('/manager/company');
    return Company.fromJson(Map<String, dynamic>.from(body['payload'] as Map));
  }

  Future<Company> save(Map<String, dynamic> fields, {XFile? logo, bool removeLogo = false}) async {
    final form = FormData.fromMap({
      ...fields.map((k, v) => MapEntry(k, v ?? '')),
      if (removeLogo) 'remove_logo': '1',
      if (logo != null) 'logo': MultipartFile.fromBytes(await logo.readAsBytes(), filename: logo.name),
    });
    final body = await api.post('/manager/company', form);
    return Company.fromJson(Map<String, dynamic>.from(body['payload'] as Map));
  }
}

/// Tampon généré à partir du nom, du métier et des téléphones de l'entreprise.
class Stamp {
  Stamp.fromJson(Map<String, dynamic> json)
      : enabled = json['enabled'] as bool? ?? false,
        color = json['color'] as String? ?? '#1E3A8A',
        image = base64Decode(json['image'] as String? ?? '');

  final bool enabled;
  final String color;
  final Uint8List image;
}

class StampRepository {
  StampRepository(this.api);

  final ApiClient api;

  /// Aperçu, éventuellement dans une autre couleur que celle enregistrée.
  Future<Stamp> preview({String? color}) async {
    final body = await api.get('/manager/company/stamp', query: {'color': color});
    return Stamp.fromJson(Map<String, dynamic>.from(body['payload'] as Map));
  }

  Future<(Stamp, String)> save({required bool enabled, required String color}) async {
    final body = await api.put('/manager/company/stamp', {'enabled': enabled, 'color': color});
    return (Stamp.fromJson(Map<String, dynamic>.from(body['payload'] as Map)), body['message'] as String? ?? '');
  }
}

const monthNames = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/// Période des chiffres de l'accueil : une année (éventuellement un mois), un jour précis,
/// ou tout l'historique (aucun champ).
class DashboardPeriod {
  const DashboardPeriod({this.year, this.month, this.date});

  /// Par défaut : le mois en cours.
  factory DashboardPeriod.currentMonth() {
    final now = DateTime.now();
    return DashboardPeriod(year: now.year, month: now.month);
  }

  final int? year;
  final int? month;
  final DateTime? date;

  bool get isAllTime => year == null && date == null;

  Map<String, dynamic> toQuery() => {
        if (date != null) 'date': '${date!.year}-${_two(date!.month)}-${_two(date!.day)}'
        else if (year != null) ...{
          'year': year,
          if (month != null) 'month': month,
        },
      };

  /// « en octobre 2026 », « en 2025 », « le 07/10/2026 », « depuis le début ».
  String get label {
    if (date != null) {
      return 'le ${_two(date!.day)}/${_two(date!.month)}/${date!.year}';
    }
    if (year == null) {
      return 'depuis le début';
    }
    return month == null ? 'en $year' : 'en ${monthNames[month! - 1]} $year';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  bool operator ==(Object other) => other is DashboardPeriod && other.year == year && other.month == month && other.date == date;

  @override
  int get hashCode => Object.hash(year, month, date);
}

class Dashboard {
  Dashboard.fromJson(Map<String, dynamic> json)
      : years = (json['years'] as List? ?? const []).map((y) => (y as num).toInt()).toList(),
        quotes = Map<String, dynamic>.from(json['quotes'] as Map? ?? const {}),
        acceptanceRate = (json['acceptance_rate'] as num?)?.toDouble(),
        month = Map<String, dynamic>.from(json['month'] as Map? ?? const {}),
        deposits = Map<String, dynamic>.from(json['deposits'] as Map? ?? const {}),
        customersCount = json['customers_count'] as int? ?? 0,
        awaiting = (json['awaiting_answer'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        subscription = Map<String, dynamic>.from(json['subscription'] as Map? ?? const {});

  /// Années proposées dans le filtre (du plus récent au plus ancien).
  final List<int> years;
  final Map<String, dynamic> quotes;
  final double? acceptanceRate;
  final Map<String, dynamic> month;
  final Map<String, dynamic> deposits;
  final int customersCount;
  final List<Map<String, dynamic>> awaiting;
  final Map<String, dynamic> subscription;

  int count(String status) => ((quotes[status] as Map?)?['count'] as int?) ?? 0;
  int total(String status) => ((quotes[status] as Map?)?['total'] as int?) ?? 0;
}

class DashboardRepository {
  DashboardRepository(this.api);

  final ApiClient api;

  Future<Dashboard> get({DashboardPeriod period = const DashboardPeriod()}) async {
    final body = await api.get('/manager/dashboard', query: period.toQuery());
    return Dashboard.fromJson(Map<String, dynamic>.from(body['payload'] as Map));
  }
}
