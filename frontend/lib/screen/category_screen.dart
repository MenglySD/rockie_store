import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/category_product_cart.dart';
import 'package:rockie_store/helpers/product_image.dart';
import 'package:rockie_store/models/category.dart';
import 'package:rockie_store/provider/product_list_controller.dart';
import 'package:rockie_store/repositories/product_repository.dart';
import 'package:rockie_store/screen/notification_screen.dart';
import 'package:rockie_store/screen/product_detail_screen.dart';
import 'package:rockie_store/screen/search_screen.dart';
import 'package:rockie_store/theme/app_colors.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  /// null = "For you" (most popular products).
  Category? activeCategory;

  List<Category> categories = const [];
  bool _loadingCategories = true;
  Object? _categoriesError;

  late final ProductListController _products;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _products = ProductListController(context.read<ProductRepository>())
      ..addListener(_onProductsChanged)
      ..load(const ProductQuery(sort: ProductSort.popular));
    _scrollController.addListener(_onScroll);
    _loadCategories();
  }

  @override
  void dispose() {
    _products
      ..removeListener(_onProductsChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onProductsChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) _products.loadMore();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoriesError = null;
    });
    try {
      final result = await context.read<ProductRepository>().categories(refresh: true);
      if (mounted) setState(() => categories = result);
    } catch (error) {
      if (mounted) setState(() => _categoriesError = error);
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  void _select(Category? category) {
    if (category?.id == activeCategory?.id) return;
    setState(() => activeCategory = category);
    _products.load(
      ProductQuery(
        categoryId: category?.id,
        sort: category == null ? ProductSort.popular : ProductSort.newest,
      ),
    );
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSidebar(),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: mainColor),
                borderRadius: BorderRadius.circular(30),
              ),

              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchScreen(),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: mainColor),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    enabled:
                        false, // Prevents keyboard pop on shop screen, acts as a button
                    decoration: InputDecoration(
                      hintText: 'Search for products...',
                      hintStyle: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: mainColor,
                        size: 20,
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SearchScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.all(16),
                          ),
                          child: const Text(
                            'Search',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: Colors.black,
              size: 24,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final entries = <Category?>[null, ...categories];
    return Container(
      width: 96,
      color: const Color(0xFFF3F2F0),
      child: ListView(
        padding: EdgeInsets.zero,
        children: entries.map((cat) {
          final isActive = cat?.id == activeCategory?.id;
          return InkWell(
            onTap: () => _select(cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              color: isActive ? Colors.white : Colors.transparent,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (isActive)
                    Positioned(
                      left: -12,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 3, color: mainColor),
                    ),
                  Text(
                    cat?.name ?? 'For you',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      color: isActive ? mainColor : Colors.black87,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopCategories() {
    if (_loadingCategories && categories.isEmpty) {
      return const SizedBox(height: 120, child: LoadingView());
    }
    if (_categoriesError != null && categories.isEmpty) {
      return SizedBox(
        height: 220,
        child: ErrorView(error: _categoriesError!, onRetry: _loadCategories),
      );
    }
    final topCategories = categories.where((c) => c.imageUrl != null).take(6).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: topCategories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, i) {
        final category = topCategories[i];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _select(category),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: productImage(category.imageUrl, width: 82, fit: BoxFit.cover),
                ),
              ),
              SizedBox(height: 8),
              Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, height: 1.1),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProducts() {
    final visibleProducts = _products.items;
    if (_products.loading && visibleProducts.isEmpty) {
      return const SizedBox(height: 200, child: LoadingView());
    }
    if (_products.error != null && visibleProducts.isEmpty) {
      return SizedBox(
        height: 260,
        child: ErrorView(error: _products.error!, onRetry: _products.retry),
      );
    }
    if (visibleProducts.isEmpty) {
      return const SizedBox(
        height: 200,
        child: EmptyView(icon: Icons.inventory_2_outlined, title: 'No products in this category yet'),
      );
    }
    return Column(
      children: [
        MasonryGridView.count(
          padding: const EdgeInsets.all(14),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          itemCount: visibleProducts.length,
          itemBuilder: (context, index) {
            final product = visibleProducts[index];
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: product),
                    ),
                  );
                },
                child: CategoryProductCart(
                  product: product,
                  discountPct: product.discountPct > 0 ? product.discountPct : null,
                ),
              ),
            );
          },
        ),
        if (_products.loadingMore)
          const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(color: mainColor),
          )
        else if (_products.error != null)
          TextButton.icon(
            onPressed: _products.retry,
            icon: const Icon(Icons.refresh, color: mainColor),
            label: const Text('Retry', style: TextStyle(color: mainColor)),
          ),
      ],
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      color: mainColor,
      onRefresh: () => Future.wait([_products.load(), _loadCategories()]),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Top Categories",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              _buildTopCategories(),

              SizedBox(height: 13),
              Text(
                activeCategory?.name ?? "You may also like",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 5),

              // product_card
              _buildProducts(),
            ],
          ),
        ],
      ),
    );
  }
}
