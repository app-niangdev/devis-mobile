import '../../core/api/api_client.dart';

class Customer {
  Customer.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        name = json['name'] as String? ?? '',
        phone = json['phone'] as String? ?? '',
        phoneDisplay = json['phone_display'] as String? ?? '',
        address = json['address'] as String?,
        email = json['email'] as String?,
        notes = json['notes'] as String?,
        quotesCount = json['quotes_count'] as int? ?? 0,
        acceptedAmount = json['accepted_amount'] as int? ?? 0,
        lastQuoteAt = json['last_quote_at'] as String?,
        quotes = (json['quotes'] as List? ?? const [])
            .map((q) => CustomerQuote.fromJson(Map<String, dynamic>.from(q as Map)))
            .toList();

  final int id;
  final String name;
  final String phone;
  final String phoneDisplay;
  final String? address;
  final String? email;
  final String? notes;
  final int quotesCount;
  final int acceptedAmount;
  final String? lastQuoteAt;
  final List<CustomerQuote> quotes;
}

class CustomerQuote {
  CustomerQuote.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        number = json['quote_number'] as String? ?? '',
        title = json['title'] as String?,
        status = json['status'] as String? ?? 'draft',
        isExpired = json['is_expired'] as bool? ?? false,
        total = json['total_amount'] as int? ?? 0,
        createdAt = json['created_at'] as String?;

  final int id;
  final String number;
  final String? title;
  final String status;
  final bool isExpired;
  final int total;
  final String? createdAt;
}

class Paged<T> {
  Paged(this.items, this.currentPage, this.lastPage, this.total);

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

class CustomersRepository {
  CustomersRepository(this.api);

  final ApiClient api;

  Future<Paged<Customer>> list({String? search, String sort = 'name', int page = 1}) async {
    final body = await api.get('/manager/customers', query: {'search': search, 'sort': sort, 'page': page, 'per_page': 30});
    final meta = Map<String, dynamic>.from(body['meta'] as Map);
    return Paged(
      (body['payload'] as List).map((c) => Customer.fromJson(Map<String, dynamic>.from(c as Map))).toList(),
      meta['current_page'] as int,
      meta['last_page'] as int,
      meta['total'] as int,
    );
  }

  Future<Customer> find(int id) async {
    final body = await api.get('/manager/customers/$id');
    return Customer.fromJson(Map<String, dynamic>.from(body['payload'] as Map));
  }

  Future<Customer> save({int? id, required Map<String, dynamic> data}) async {
    final body = id == null ? await api.post('/manager/customers', data) : await api.put('/manager/customers/$id', data);
    return Customer.fromJson(Map<String, dynamic>.from(body['payload'] as Map));
  }

  Future<void> delete(int id) => api.delete('/manager/customers/$id');
}
