import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/product_card.dart';
import 'package:rockie_store/provider/product_list_controller.dart';
import 'package:rockie_store/repositories/product_repository.dart';
import 'package:rockie_store/screen/product_detail_screen.dart';
import 'package:rockie_store/theme/app_colors.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;

  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  final List<String> _recentSearches = [
    'Loafers',
    'Winter Sweater',
    'Jacket',
    'Long-Sleeved',
  ];
  final List<String> _trendingSearches = [
    'Wide-Leg Pants',
    'Slip-On Loafers',
    'Spider-Man Costume',
  ];

  String _query = '';
  late final ProductListController _products;
  final ScrollController _resultsScroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _searchController = TextEditingController(text: _query);
    _products = ProductListController(context.read<ProductRepository>())
      ..addListener(_onProductsChanged);
    _resultsScroll.addListener(_onScroll);
    if (_query.trim().isNotEmpty) _runSearch(_query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _resultsScroll.dispose();
    _products
      ..removeListener(_onProductsChanged)
      ..dispose();
    super.dispose();
  }

  void _onProductsChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    final position = _resultsScroll.position;
    if (position.pixels >= position.maxScrollExtent - 400) _products.loadMore();
  }

  /// GET /products?q=... — the server does the matching.
  void _runSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    _products.load(ProductQuery(q: query, sort: ProductSort.popular));
  }

  /// While typing: wait for a short pause before calling the API.
  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(value));
  }

  void _searchFor(String value) {
    final query = value.trim();
    _debounce?.cancel();
    setState(() => _query = query);
    _runSearch(query);
    if (query.isNotEmpty) {
      _recentSearches.removeWhere(
        (item) => item.toLowerCase() == query.toLowerCase(),
      );
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 8) _recentSearches.removeLast();
    }
  }

  void _selectQuery(String query) {
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _searchFor(query);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  ),
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: _onQueryChanged,
                        onSubmitted: _searchFor,
                        decoration: InputDecoration(
                          hintText: 'Search products, brands...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9E9E9E),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.black87,
                          ),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _debounce?.cancel();
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close, size: 19),
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  GestureDetector(
                    onTap: () {
                      _searchFor(_searchController.text);
                      FocusScope.of(context).unfocus();
                    },
                    child: const Text(
                      'Search',
                      style: TextStyle(
                        color: mainColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? _buildDiscover()
                  : _products.loading && _products.items.isEmpty
                  ? const LoadingView()
                  : _products.error != null && _products.items.isEmpty
                  ? ErrorView(error: _products.error!, onRetry: _products.retry)
                  : _products.items.isEmpty
                  ? _buildNoResults()
                  : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscover() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.history, size: 18, color: Colors.black87),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Recent Searches',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => setState(_recentSearches.clear),
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: mainColor, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: _recentSearches
                .map(
                  (query) => ActionChip(
                    avatar: const Icon(
                      Icons.history,
                      size: 15,
                      color: Colors.black54,
                    ),
                    label: Text(query),
                    onPressed: () => _selectQuery(query),
                    backgroundColor: const Color(0xFFECEEEF),
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 26),
        ],
        const Row(
          children: [
            Icon(Icons.trending_up, size: 18, color: mainColor),
            SizedBox(width: 7),
            Text(
              'Trending Now',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._trendingSearches.asMap().entries.map(
          (entry) => ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Text(
              '#${entry.key + 1}',
              style: const TextStyle(
                color: mainColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            title: Text(
              entry.value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(
              Icons.north_east,
              size: 16,
              color: Color(0xFF999999),
            ),
            onTap: () => _selectQuery(entry.value),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final results = _products.items;
    return CustomScrollView(
      controller: _resultsScroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Text(
              '${_products.total} results for “${_query.trim()}”',
              style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childCount: results.length,
            itemBuilder: (context, index) {
              final product = results[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product),
                  ),
                ),
                child: ProductCard(product: product),
              );
            },
          ),
        ),
        if (_products.loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Center(child: CircularProgressIndicator(color: mainColor)),
            ),
          )
        else if (_products.error != null)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton.icon(
                onPressed: _products.retry,
                icon: const Icon(Icons.refresh, color: mainColor),
                label: const Text('Retry', style: TextStyle(color: mainColor)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_outlined,
              size: 58,
              color: Color(0xFFB5B5B5),
            ),
            const SizedBox(height: 12),
            const Text(
              'No products found',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Try another search for “${_query.trim()}”.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
