import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/product_image.dart';
import 'package:rockie_store/models/banner.dart';
import 'package:rockie_store/models/category.dart';
import 'package:rockie_store/provider/product_list_controller.dart';
import 'package:rockie_store/repositories/product_repository.dart';
import 'package:rockie_store/screen/notification_screen.dart';
import 'package:rockie_store/screen/product_detail_screen.dart';
import 'package:rockie_store/screen/search_screen.dart';
import 'package:rockie_store/theme/app_colors.dart';
import 'package:rockie_store/helpers/product_card.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreen();
}

/// A filter chip: "All", "Rating" (sort by rating), "Women" or "Men".
class _FilterTab {
  final String label;
  final List<int> categoryIds;
  final ProductSort sort;
  const _FilterTab(this.label, {this.categoryIds = const [], this.sort = ProductSort.newest});
}

class _ShopScreen extends State<ShopScreen> with AutomaticKeepAliveClientMixin {
  List<PromoBanner> _banners = const [];
  bool _bannersLoading = true;

  int currentSlideIndex = 0;
  int selectedFilterIndex = 0;

  List<_FilterTab> filterTabs = const [
    _FilterTab('All'),
    _FilterTab('Rating', sort: ProductSort.rating),
  ];

  late final ProductListController _products;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _products = ProductListController(context.read<ProductRepository>())
      ..addListener(_onProductsChanged)
      ..load();
    _scrollController.addListener(_onScroll);
    _loadCategories();
    _loadBanners();
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

  /// Infinite scroll: load the next page near the bottom.
  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) _products.loadMore();
  }

  /// "Women" and "Men" cover every category whose slug starts with
  /// "womens-" / "mens-" (clothing and shoes).
  Future<void> _loadCategories() async {
    try {
      final categories = await context.read<ProductRepository>().categories();
      if (!mounted) return;
      List<int> idsWithPrefix(String prefix) => [
        for (final Category category in categories)
          if (category.slug.startsWith(prefix)) category.id,
      ];
      final women = idsWithPrefix('womens-');
      final men = idsWithPrefix('mens-');
      final selectedLabel = filterTabs[selectedFilterIndex].label;
      final tabs = [
        const _FilterTab('All'),
        const _FilterTab('Rating', sort: ProductSort.rating),
        if (women.isNotEmpty) _FilterTab('Women', categoryIds: women),
        if (men.isNotEmpty) _FilterTab('Men', categoryIds: men),
      ];
      setState(() {
        filterTabs = tabs;
        // Keep the chosen chip after a pull-to-refresh.
        selectedFilterIndex = tabs.indexWhere((tab) => tab.label == selectedLabel).clamp(0, tabs.length - 1);
      });
    } catch (_) {
      // "Women" and "Men" need the categories; "All" and "Rating" still work.
    }
  }

  Future<void> _loadBanners() async {
    try {
      final banners = await context.read<ProductRepository>().banners();
      if (!mounted) return;
      setState(() {
        _banners = banners;
        if (currentSlideIndex >= banners.length) currentSlideIndex = 0;
      });
    } catch (_) {
      // The slider is optional; it stays hidden until a refresh succeeds.
    } finally {
      if (mounted) setState(() => _bannersLoading = false);
    }
  }

  void _openBanner(PromoBanner banner) {
    final productId = banner.productId;
    if (productId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen.id(productId)),
    );
  }

  ProductQuery get _query {
    final tab = filterTabs[selectedFilterIndex];
    return ProductQuery(categoryIds: tab.categoryIds, sort: tab.sort);
  }

  void _selectFilter(int index) {
    if (index == selectedFilterIndex) return;
    setState(() => selectedFilterIndex = index);
    _products.load(_query);
  }

  Future<void> _refresh() async {
    await Future.wait([_products.load(_query), _loadCategories(), _loadBanners()]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final visibleProducts = _products.items;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: mainColor,
          onRefresh: _refresh,
          child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Logo + bell — scrolls away normally
            SliverToBoxAdapter(child: _buildTopBar(context)),

            // Search bar — pins to the top once it reaches it
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchBarDelegate(
                child: Container(color: Colors.white, child: _buildSearchBar(context)),
                height: 72,
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildCarousel(),
                  const SizedBox(height: 20),
                  _buildFilterChips(),
                  const SizedBox(height: 20),
                  _buildRecommendedHeader(),
                ],
              ),
            ),

            if (_products.loading && visibleProducts.isEmpty)
              const SliverToBoxAdapter(
                child: SizedBox(height: 240, child: LoadingView()),
              )
            else if (_products.error != null && visibleProducts.isEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 300,
                  child: ErrorView(error: _products.error!, onRetry: _products.retry),
                ),
              )
            else if (visibleProducts.isEmpty)
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 240,
                  child: EmptyView(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products here yet',
                  ),
                ),
              )
            else
            // Product grid as a sliver so it scrolls with everything else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childCount: visibleProducts.length,
                itemBuilder: (context, index) {
                  final product = visibleProducts[index];
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailScreen(product: product),
                          ),
                        );
                      },
                      child: ProductCard(product: product),
                    ),
                  );
                },
              ),
            ),

            SliverToBoxAdapter(child: _buildListFooter()),
          ],
          ),
        ),
      ),
    );
  }

  /// Spinner while loading the next page, or a retry button if it failed.
  Widget _buildListFooter() {
    if (_products.loadingMore) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: Center(child: CircularProgressIndicator(color: mainColor)),
      );
    }
    if (_products.error != null && _products.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Center(
          child: TextButton.icon(
            onPressed: _products.retry,
            icon: const Icon(Icons.refresh, color: mainColor),
            label: Text(errorMessage(_products.error!), style: const TextStyle(color: mainColor)),
          ),
        ),
      );
    }
    return const SizedBox(height: 8);
  }

  Widget _buildTopBar(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Image.asset('assets/images/logo.png', width: 105, height: 30),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black, size: 24),
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

  Widget _buildCarousel() {
    if (_banners.isEmpty) {
      // Same size as the slider while loading, so the page doesn't jump.
      if (!_bannersLoading) return const SizedBox.shrink();
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: productImage('', width: double.infinity, height: 160),
      );
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CarouselSlider(
          items: [
            for (final PromoBanner banner in _banners)
              GestureDetector(
                onTap: () => _openBanner(banner),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: productImage(banner.imageUrl, width: 400, height: 160),
                ),
              ),
          ],
          options: CarouselOptions(
            height: 160,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            viewportFraction: 1,
            onPageChanged: (index, reason) {
              setState(() {
                currentSlideIndex = index;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int index = 0; index < _banners.length; index++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: currentSlideIndex == index ? 16 : 6,
                  height: 6,
                  margin: EdgeInsets.only(
                    right: index == _banners.length - 1 ? 0 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: currentSlideIndex == index
                        ? const Color(0xFFFF4400)
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int index = 0; index < filterTabs.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  right: index == filterTabs.length - 1 ? 0 : 8,
                ),
                child: FilterChip(
                  showCheckmark: false,
                  onSelected: (_) => _selectFilter(index),
                  selected: selectedFilterIndex == index,
                  label: Text(
                    filterTabs[index].label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: selectedFilterIndex == index
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFFFF4400),
                  side: BorderSide(
                    color: selectedFilterIndex == index
                        ? const Color(0xFFFF4400)
                        : Colors.grey.shade400,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Recommended',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _products.total > 0 ? '${_products.total} items' : '',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFFFF4400),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

Widget _buildSearchBar(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchScreen()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: mainColor),
          borderRadius: BorderRadius.circular(30),
        ),
        child: TextField(
          enabled: false, // Prevents keyboard pop on shop screen, acts as a button
          decoration: InputDecoration(
            hintText: 'Search for products...',
            hintStyle: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            prefixIcon: Icon(Icons.search, color: mainColor, size: 20),
            suffixIcon: Padding(
              padding: const EdgeInsets.all(4),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
                child: const Text(
                  'Search',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Pins the search bar to the top of the CustomScrollView once it reaches
/// it, like a sticky header. Height is fixed (72) so scroll math stays
/// simple — bump minExtent/maxExtent together if you resize the search bar.
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SearchBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _SearchBarDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}
