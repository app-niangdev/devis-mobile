import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/data_changes.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/theme/app_theme.dart';
import 'customer.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> with ReloadOnDataChange {
  static const _sorts = {'name': 'A → Z', 'recent': 'Récents', 'accepted': 'Meilleurs clients'};

  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  String _sort = 'name';

  final List<Customer> _items = [];
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300 && _hasMore && !_loading) {
        _load(more: true);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<CustomersRepository>().list(search: _search.text.trim(), sort: _sort, page: more ? _page + 1 : 1);
      if (!mounted) {
        return;
      }
      setState(() {
        if (!more) {
          _items.clear();
        }
        _items.addAll(page.items);
        _page = page.currentPage;
        _hasMore = page.hasMore;
        _total = page.total;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void onDataChanged() => _load();

  Future<void> _open(String path) => context.push(path);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_total > 0 ? 'Clients ($_total)' : 'Clients', style: const TextStyle(fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(hintText: 'Nom ou téléphone', prefixIcon: Icon(Icons.search), isDense: true),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _load);
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nouveau client',
        onPressed: () => _open('/customers/new'),
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                for (final entry in _sorts.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _sort == entry.key,
                      onSelected: (_) {
                        setState(() => _sort = entry.key);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  Widget _list() {
    if (_error != null && _items.isEmpty) {
      return ErrorView(error: _error!, onRetry: _load);
    }
    if (_loading && _items.isEmpty) {
      return const LoadingView();
    }
    if (_items.isEmpty) {
      return EmptyView(
        icon: Icons.people_outline,
        message: _search.text.isEmpty ? 'Aucun client pour le moment.' : 'Aucun client ne correspond.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final c = _items[index];
          return Card(
            child: ListTile(
              onTap: () => _open('/customers/${c.id}'),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                    style: TextStyle(color: context.brand.primaryInk, fontWeight: FontWeight.w700)),
              ),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(c.phoneDisplay),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${c.quotesCount} devis', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                  if (c.acceptedAmount > 0)
                    Text(formatMoney(c.acceptedAmount), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF16A34A), fontSize: 13)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
