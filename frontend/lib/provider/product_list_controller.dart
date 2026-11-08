import 'package:flutter/foundation.dart';
import 'package:rockie_store/models/product.dart';
import 'package:rockie_store/repositories/product_repository.dart';
import 'package:rockie_store/services/api_exception.dart';

/// Paginated product list with infinite scroll, shared by the home,
/// category and search screens.
class ProductListController extends ChangeNotifier {
  final ProductRepository _repository;
  final int perPage;

  ProductListController(this._repository, {this.perPage = 20});

  ProductQuery _query = const ProductQuery();
  ProductQuery get query => _query;

  final List<Product> _items = [];
  List<Product> get items => List.unmodifiable(_items);

  int _page = 0;
  int _total = 0;
  int get total => _total;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  bool _loading = false;
  bool get loading => _loading;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  ApiException? _error;
  ApiException? get error => _error;

  /// Ignores responses from requests that were superseded by a newer query.
  int _generation = 0;
  bool _disposed = false;

  Future<void> load([ProductQuery? query]) async {
    if (query != null) _query = query;
    final generation = ++_generation;
    _loading = true;
    _loadingMore = false;
    _error = null;
    _items.clear();
    _page = 0;
    _hasMore = true;
    _notify();

    try {
      final page = await _repository.products(_query, page: 1, perPage: perPage);
      if (generation != _generation) return;
      _items.addAll(page.items);
      _page = page.currentPage;
      _total = page.total;
      _hasMore = page.hasMore;
    } on ApiException catch (e) {
      if (generation != _generation) return;
      _error = e;
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _error != null) return;
    final generation = _generation;
    _loadingMore = true;
    _notify();
    try {
      final page = await _repository.products(_query, page: _page + 1, perPage: perPage);
      if (generation != _generation) return;
      _items.addAll(page.items);
      _page = page.currentPage;
      _total = page.total;
      _hasMore = page.hasMore;
    } on ApiException catch (e) {
      if (generation != _generation) return;
      _error = e;
    } finally {
      if (generation == _generation) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  /// Retry after an error: reload from scratch, or continue paging.
  Future<void> retry() {
    if (_items.isEmpty) return load();
    _error = null;
    return loadMore();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
