import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/data_changes.dart';
import '../../core/widgets/common.dart';
import 'quote.dart';
import 'quote_widgets.dart';

/// Liste des devis, filtrée par statut, avec recherche.
class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key, this.initialStatus});

  final String? initialStatus;

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> with ReloadOnDataChange {
  static const _filters = [null, 'draft', 'sent', 'accepted', 'refused', 'expired'];

  late String? _status = widget.initialStatus;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  final List<QuoteSummary> _items = [];
  Map<String, int> _counts = {};
  int _page = 1;
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
  void didUpdateWidget(covariant QuotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStatus != oldWidget.initialStatus) {
      _status = widget.initialStatus;
      _load();
    }
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
      final page = more ? _page + 1 : 1;
      final (result, summary) = await context.read<QuotesRepository>().list(status: _status, search: _search.text.trim(), page: page);
      if (!mounted) {
        return;
      }
      setState(() {
        if (!more) {
          _items.clear();
        }
        _items.addAll(result.items);
        _page = result.currentPage;
        _hasMore = result.hasMore;
        _counts = summary.counts;
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

  int? _countFor(String? status) {
    if (status == null) {
      return null;
    }
    return _counts[status];
  }

  @override
  void onDataChanged() => _load();

  Future<void> _open(String path) => context.push(path);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devis', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'N°, client, téléphone, objet…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _load);
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open('/quotes/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau devis'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                for (final status in _filters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text([
                        status == null ? 'Tous' : quoteStatusLabels[status]!,
                        if (_countFor(status) != null) '(${_countFor(status)})',
                      ].join(' ')),
                      selected: _status == status,
                      onSelected: (_) {
                        setState(() => _status = status);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_error != null && _items.isEmpty) {
      return ErrorView(error: _error!, onRetry: _load);
    }
    if (_loading && _items.isEmpty) {
      return const LoadingView();
    }
    if (_items.isEmpty) {
      return EmptyView(
        icon: Icons.request_quote_outlined,
        message: _search.text.isEmpty && _status == null ? 'Aucun devis pour le moment.\nCréez votre premier devis !' : 'Aucun devis ne correspond.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(padding: EdgeInsets.all(16), child: LoadingView());
          }
          final quote = _items[index];
          return QuoteTile(quote: quote, onTap: () => _open('/quotes/${quote.id}'));
        },
      ),
    );
  }
}
