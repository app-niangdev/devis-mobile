import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../customers/customer.dart';

const quoteStatusLabels = {
  'draft': 'Brouillon',
  'sent': 'Envoyé',
  'accepted': 'Accepté',
  'refused': 'Refusé',
  'expired': 'Expiré',
};

const paymentMethodLabels = {
  'wave': 'Wave',
  'orange_money': 'Orange Money',
  'free_money': 'Free Money',
  'cash': 'Espèces',
};

const commonUnits = ['u', 'm²', 'ml', 'm³', 'kg', 'sac', 'forfait', 'jour', 'heure'];

Color quoteStatusColor(String status) => switch (status) {
      'sent' => const Color(0xFF2563EB),
      'accepted' => const Color(0xFF16A34A),
      'refused' => const Color(0xFFDC2626),
      'expired' => const Color(0xFFD97706),
      _ => const Color(0xFF64748B),
    };

/// Désignation des lignes de main-d'œuvre (le gestionnaire ne saisit que le montant).
const laborDesignation = 'Main-d\'œuvre';

class QuoteLine {
  QuoteLine({
    this.productId,
    this.kind = 'supply',
    this.designation = '',
    this.unitName,
    this.quantity = 1,
    this.unitPrice = 0,
  });

  QuoteLine.fromJson(Map<String, dynamic> json)
      : productId = json['product_id'] as int?,
        kind = json['kind'] as String? ?? 'supply',
        designation = json['designation'] as String? ?? '',
        unitName = json['unit_name'] as String?,
        quantity = (json['quantity'] as num? ?? 1).toDouble(),
        unitPrice = (json['unit_price'] as num? ?? 0).round();

  int? productId;
  String kind;
  String designation;
  String? unitName;
  double quantity;
  int unitPrice;

  int get subtotal => (quantity * unitPrice).round();
  bool get isLabor => kind == 'labor';

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'kind': kind,
        'designation': designation,
        'unit_name': unitName,
        'quantity': quantity,
        'unit_price': unitPrice,
      };

  QuoteLine copy() => QuoteLine(
        productId: productId,
        kind: kind,
        designation: designation,
        unitName: unitName,
        quantity: quantity,
        unitPrice: unitPrice,
      );
}

class QuoteSummary {
  QuoteSummary.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        number = json['quote_number'] as String? ?? '',
        title = json['title'] as String?,
        status = json['status'] as String? ?? 'draft',
        isExpired = json['is_expired'] as bool? ?? false,
        customerName = (json['customer'] as Map?)?['name'] as String? ?? 'Client',
        total = json['total_amount'] as int? ?? 0,
        depositAmount = json['deposit_amount'] as int? ?? 0,
        depositStatus = json['deposit_status'] as String? ?? 'none',
        validUntil = json['valid_until'] as String?,
        createdAt = json['created_at'] as String?;

  final int id;
  final String number;
  final String? title;
  final String status;
  final bool isExpired;
  final String customerName;
  final int total;
  final int depositAmount;
  final String depositStatus;
  final String? validUntil;
  final String? createdAt;

  /// Statut affiché : « expiré » remplace brouillon / envoyé après la date de validité.
  String get displayStatus => isExpired ? 'expired' : status;
}

class Quote extends QuoteSummary {
  Quote.fromJson(super.json)
      : customer = Map<String, dynamic>.from(json['customer'] as Map? ?? const {}),
        notes = json['notes'] as String?,
        suppliesAmount = json['supplies_amount'] as int? ?? 0,
        laborAmount = json['labor_amount'] as int? ?? 0,
        grossAmount = json['gross_amount'] as int? ?? 0,
        discount = json['discount'] as int? ?? 0,
        depositType = json['deposit_type'] as String? ?? 'none',
        depositValue = json['deposit_value'] as int? ?? 0,
        balanceAmount = json['balance_amount'] as int? ?? 0,
        depositReceived = json['deposit_received'] is Map ? Map<String, dynamic>.from(json['deposit_received'] as Map) : null,
        isEditable = json['is_editable'] as bool? ?? false,
        sourceNumber = json['source_number'] as String?,
        whatsappAvailable = json['whatsapp_available'] as bool? ?? false,
        items = (json['items'] as List? ?? const [])
            .map((i) => QuoteLine.fromJson(Map<String, dynamic>.from(i as Map)))
            .toList(),
        super.fromJson();

  final Map<String, dynamic> customer;
  final String? notes;
  final int suppliesAmount;
  final int laborAmount;
  final int grossAmount;
  final int discount;
  final String depositType;
  final int depositValue;
  final int balanceAmount;
  final Map<String, dynamic>? depositReceived;
  final bool isEditable;
  final String? sourceNumber;
  final bool whatsappAvailable;
  final List<QuoteLine> items;

  int get customerId => customer['id'] as int? ?? 0;
}

class QuotesSummary {
  QuotesSummary(this.counts);

  final Map<String, int> counts;
}

class CatalogProduct {
  CatalogProduct.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        name = json['name'] as String? ?? '',
        unitPrice = double.tryParse('${json['unit_price']}')?.round() ?? 0;

  final int id;
  final String name;
  final int unitPrice;
}

class QuotesRepository {
  QuotesRepository(this.api);

  final ApiClient api;

  Future<(Paged<QuoteSummary>, QuotesSummary)> list({String? status, String? search, int? customerId, int page = 1}) async {
    final body = await api.get('/manager/quotes', query: {
      'status': status,
      'search': search,
      'customer_id': customerId,
      'page': page,
      'per_page': 25,
    });
    final meta = Map<String, dynamic>.from(body['meta'] as Map);
    final summary = Map<String, dynamic>.from(body['summary'] as Map? ?? const {});
    return (
      Paged(
        (body['payload'] as List).map((q) => QuoteSummary.fromJson(Map<String, dynamic>.from(q as Map))).toList(),
        meta['current_page'] as int,
        meta['last_page'] as int,
        meta['total'] as int,
      ),
      QuotesSummary(summary.map((k, v) => MapEntry(k, ((v as Map)['count'] as int?) ?? 0))),
    );
  }

  Future<Quote> find(int id) async => _quote(await api.get('/manager/quotes/$id'));

  Future<(Quote, String)> save({int? id, required Map<String, dynamic> data}) async {
    final body = id == null ? await api.post('/manager/quotes', data) : await api.put('/manager/quotes/$id', data);
    return (_quote(body), body['message'] as String? ?? 'Devis enregistré.');
  }

  Future<(Quote, String)> action(int id, String action, [Map<String, dynamic>? data]) async {
    final body = await api.post('/manager/quotes/$id/$action', data);
    return (_quote(body), body['message'] as String? ?? '');
  }

  Future<(Quote, String)> recordDeposit(int id, Map<String, dynamic> data) async {
    final body = await api.put('/manager/quotes/$id/deposit', data);
    return (_quote(body), body['message'] as String? ?? '');
  }

  Future<(Quote, String)> cancelDeposit(int id) async {
    final body = await api.delete('/manager/quotes/$id/deposit');
    return (_quote(body), body['message'] as String? ?? '');
  }

  Future<String> delete(int id) async => (await api.delete('/manager/quotes/$id'))['message'] as String? ?? '';

  Future<Uint8List> pdf(int id) => api.getBytes('/manager/quotes/$id/pdf');

  Future<List<CatalogProduct>> products(String search) async {
    final body = await api.get('/manager/products/list', query: {'search': search, 'per_page': 20});
    return (body['payload'] as List).map((p) => CatalogProduct.fromJson(Map<String, dynamic>.from(p as Map))).toList();
  }

  Quote _quote(Map<String, dynamic> body) => Quote.fromJson(Map<String, dynamic>.from(body['payload'] as Map));
}
