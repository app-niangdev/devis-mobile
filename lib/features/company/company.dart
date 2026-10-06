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

class Dashboard {
  Dashboard.fromJson(Map<String, dynamic> json)
      : quotes = Map<String, dynamic>.from(json['quotes'] as Map? ?? const {}),
        acceptanceRate = (json['acceptance_rate'] as num?)?.toDouble(),
        month = Map<String, dynamic>.from(json['month'] as Map? ?? const {}),
        deposits = Map<String, dynamic>.from(json['deposits'] as Map? ?? const {}),
        customersCount = json['customers_count'] as int? ?? 0,
        awaiting = (json['awaiting_answer'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        subscription = Map<String, dynamic>.from(json['subscription'] as Map? ?? const {});

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

  Future<Dashboard> get() async {
    final body = await api.get('/manager/dashboard');
    return Dashboard.fromJson(Map<String, dynamic>.from(body['payload'] as Map));
  }
}
