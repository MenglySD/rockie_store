import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/icon_button.dart';
import 'package:rockie_store/helpers/lightbox.dart';
import 'package:rockie_store/helpers/product_image.dart';
import 'package:rockie_store/helpers/selection_sheet.dart';
import 'package:rockie_store/provider/cart_provider.dart';
import 'package:rockie_store/repositories/product_repository.dart';
import 'package:rockie_store/screen/cart_screen.dart';
import 'package:rockie_store/screen/search_screen.dart';

import '../models/product.dart';
import '../models/review.dart';
import '../theme/app_colors.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  /// List data shown while the full detail loads.
  final Product? initial;

  ProductDetailScreen({super.key, required Product product})
    : productId = product.id,
      initial = product;

  /// Open by ID only, e.g. from an order line.
  const ProductDetailScreen.id(this.productId, {super.key}) : initial = null;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreen();
}

class _ProductDetailScreen extends State<ProductDetailScreen> {
  late final PageController _heroController;
  int _mainIndex = 0;
  bool _showAllReviews = false;
  bool _wishlisted = false;

  Product? _product;
  bool _loading = true;
  Object? _error;

  // "View All" reviews, paged from /products/{id}/reviews.
  final List<Review> _allReviews = [];
  int _reviewsPage = 0;
  bool _reviewsHasMore = true;
  bool _reviewsLoading = false;

  @override
  void initState() {
    super.initState();
    _heroController = PageController();
    _product = widget.initial;
    _load();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final product = await context.read<ProductRepository>().product(widget.productId);
      if (mounted) setState(() => _product = product);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreReviews() async {
    if (_reviewsLoading || !_reviewsHasMore) return;
    setState(() => _reviewsLoading = true);
    try {
      final page = await context.read<ProductRepository>().reviews(
        widget.productId,
        page: _reviewsPage + 1,
      );
      if (!mounted) return;
      setState(() {
        _allReviews.addAll(page.items);
        _reviewsPage = page.currentPage;
        _reviewsHasMore = page.hasMore;
      });
    } catch (error) {
      if (mounted) showApiError(context, error, onRetry: _loadMoreReviews);
    } finally {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  void _toggleReviews() {
    setState(() => _showAllReviews = !_showAllReviews);
    if (_showAllReviews && _allReviews.isEmpty) _loadMoreReviews();
  }

  void _goTo(int i) {
    final total = _product?.images.length ?? 0;
    if (total == 0) return;
    final next = ((i % total) + total) % total;
    _heroController.animateToPage(
      next,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _openLightbox(List<String> images, int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, _, _) =>
            Lightbox(images: images, initialIndex: index),
      ),
    );
  }

  void _showSelectionSheet(BuildContext context) {
    final product = _product;
    if (product == null) return;
    showProductOptions(context, product);
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    if (p == null) {
      return Scaffold(
        body: Stack(
          children: [
            _loading
                ? const LoadingView()
                : ErrorView(error: _error ?? 'Not found', onRetry: _load),
            _HeaderIcons(onBack: () => Navigator.of(context).pop()),
          ],
        ),
      );
    }

    final images = p.images;
    final visibleReviews = _showAllReviews
        ? (_allReviews.isEmpty ? p.reviews : _allReviews)
        : p.reviews.take(1).toList();
    // Detail is loaded once variants are known; until then actions wait.
    final detailLoaded = p.variants.isNotEmpty || (!_loading && _error == null);

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            color: mainColor,
            onRefresh: _load,
            child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 90),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroCarousel(
                  images: images,
                  controller: _heroController,
                  index: _mainIndex,
                  onPageChanged: (i) => setState(() => _mainIndex = i),
                  onPrev: () => _goTo(_mainIndex - 1),
                  onNext: () => _goTo(_mainIndex + 1),
                ),
                _ThumbnailStrip(
                  images: images,
                  selectedIndex: _mainIndex,
                  onSelect: _goTo,
                ),
                _TitleAndPrice(product: p),
                if (p.description != null && p.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      p.description!,
                      style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade700),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, color: mainColor),
                      label: Text(errorMessage(_error!), style: const TextStyle(color: mainColor)),
                    ),
                  ),
                _ReviewsSection(
                  product: p,
                  visibleReviews: visibleReviews,
                  showAllReviews: _showAllReviews,
                  onToggleShowAll: _toggleReviews,
                  onOpenImage: _openLightbox,
                  loadingMore: _reviewsLoading,
                  canLoadMore: _showAllReviews && _reviewsHasMore && _allReviews.isNotEmpty,
                  onLoadMore: _loadMoreReviews,
                ),
              ],
            ),
          ),
          ),
          _HeaderIcons(onBack: () => Navigator.of(context).pop()),
          _BottomActionBar(
            wishlisted: _wishlisted,
            inStock: p.inStock,
            enabled: detailLoaded,
            onToggleWishlist: () => setState(() => _wishlisted = !_wishlisted),
            onAddToCart: () => _showSelectionSheet(context),
          ),
        ],
      ),
    );
  }
}

/// Full-screen hero image carousel with dot pagination and side arrows.
class _HeroCarousel extends StatelessWidget {
  final List<String> images;
  final PageController controller;
  final int index;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _HeroCarousel({
    required this.images,
    required this.controller,
    required this.index,
    required this.onPageChanged,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 400,
          width: double.infinity,
          child: images.isEmpty
              ? productImage(null)
              : PageView.builder(
                  controller: controller,
                  itemCount: images.length,
                  onPageChanged: onPageChanged,
                  itemBuilder: (context, i) => productImage(images[i]),
                ),
        ),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (i) {
              final active = i == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? mainColor : Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// Horizontal thumbnail scroll below the hero image; tapping a thumbnail
/// jumps the hero carousel and highlights the selected thumbnail.
class _ThumbnailStrip extends StatelessWidget {
  final List<String> images;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _ThumbnailStrip({
    required this.images,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? mainColor : Colors.transparent,
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: productImage(images[i]),
            ),
          );
        },
      ),
    );
  }
}

/// Product title, current/original price, discount badge, and sold count.
class _TitleAndPrice extends StatelessWidget {
  final Product product;
  const _TitleAndPrice({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                p.price.format(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: mainColor,
                ),
              ),
              const SizedBox(width: 10),
              if (p.hasDiscount)
              Text(
                p.originalPrice.format(),
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const Spacer(),
              if (p.discountPct > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: mainColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${p.discountPct}% OFF",
                  style: const TextStyle(
                    color: mainColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Text(
              p.inStock ? "${p.sold} Sold" : "${p.sold} Sold · Out of stock",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFFA000), size: 16),
              const SizedBox(width: 4),
              Text(
                p.rating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text(
                '${p.reviewCount} reviews',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Customer Reviews header (with View All / Show Less toggle) and list.
class _ReviewsSection extends StatelessWidget {
  final Product product;
  final List<Review> visibleReviews;
  final bool showAllReviews;
  final VoidCallback onToggleShowAll;
  final void Function(List<String> images, int index) onOpenImage;
  final bool loadingMore;
  final bool canLoadMore;
  final VoidCallback onLoadMore;

  const _ReviewsSection({
    required this.product,
    required this.visibleReviews,
    required this.showAllReviews,
    required this.onToggleShowAll,
    required this.onOpenImage,
    required this.loadingMore,
    required this.canLoadMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Customer Reviews",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              if (p.reviewCount > 1 && p.reviews.isNotEmpty)
                GestureDetector(
                  onTap: onToggleShowAll,
                  child: Text(
                    showAllReviews ? "Show Less" : "View All",
                    style: const TextStyle(
                      color: mainColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (visibleReviews.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'No reviews yet.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ),
          ...visibleReviews.map(
            (rev) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ReviewAvatar(review: rev),
                      const SizedBox(width: 8),
                      Text(
                        rev.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.star, size: 12, color: const Color(0xFFFFA000)),
                      Text('${rev.rating}', style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 8),
                      Text(
                        rev.date,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rev.text,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  if (rev.images.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      runSpacing: 8,
                      children: List.generate(rev.images.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => onOpenImage(rev.images, i),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: productImage(
                                rev.images[i],
                                width: 78,
                                height: 78,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (loadingMore)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Center(child: CircularProgressIndicator(color: mainColor)),
            )
          else if (canLoadMore)
            Center(
              child: TextButton(
                onPressed: onLoadMore,
                child: const Text('Load more reviews', style: TextStyle(color: mainColor)),
              ),
            ),
        ],
      ),
    );
  }
}

/// The 4 icon buttons (back, search, cart, more) overlaid on the hero image.
class _HeaderIcons extends StatelessWidget {
  final VoidCallback onBack;
  const _HeaderIcons({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleIconButton(
            icon: Image.asset('assets/images/icon/backIcon.png'),
            onTap: onBack,
          ),
          Row(
            children: [
              CircleIconButton(
                icon: Image.asset('assets/images/icon/searchIcon.png'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              CircleIconButton(
                icon: Badge(
                  isLabelVisible: context.watch<CartProvider>().itemCount > 0,
                  label: Text('${context.watch<CartProvider>().itemCount}'),
                  child: Image.asset(
                    'assets/images/icon/Shopping Cart.png',
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CartScreen()),
                  );
                },
              ),
              const SizedBox(width: 8),
              CircleIconButton(
                icon: Image.asset('assets/images/icon/shareLinkIcon.png'),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fixed bottom bar: Cart + Wishlist icon buttons, Add to Cart, Buy Now.
class _BottomActionBar extends StatelessWidget {
  final bool wishlisted;
  final bool inStock;
  final bool enabled;
  final VoidCallback onToggleWishlist;
  final VoidCallback onAddToCart;

  const _BottomActionBar({
    required this.wishlisted,
    required this.inStock,
    required this.enabled,
    required this.onToggleWishlist,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  },
                  icon: Image.asset('assets/images/icon/Shopping Cart.png'),
                ),
                Text(
                  "Cart",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onToggleWishlist,
                  icon: wishlisted
                      ? Image.asset('assets/images/icon/HeartOrange.png')
                      : Image.asset('assets/images/icon/Heart.png'),
                ),
                Text(
                  "Wishlist",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: enabled && inStock ? onAddToCart : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: mainColor,
                  side: BorderSide(color: Color(0xFFFF4400), width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  inStock ? "Add to Cart" : "Out of stock",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                // Choose color/size first; the sheet's "Buy now" goes to checkout.
                onPressed: enabled && inStock ? onAddToCart : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF4400),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Buy Now",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reviewer's photo; their initial (or the sample review's emoji) when
/// there is no photo or it cannot be loaded.
class _ReviewAvatar extends StatelessWidget {
  final Review review;
  const _ReviewAvatar({required this.review});

  static const double _size = 32;

  @override
  Widget build(BuildContext context) {
    final isEmoji = !review.avatarIsImage && review.avatar.isNotEmpty;
    final fallback = CircleAvatar(
      radius: _size / 2,
      backgroundColor: isEmoji ? Colors.grey.shade100 : mainColor.withValues(alpha: .12),
      child: Text(
        isEmoji ? review.avatar : review.initial,
        style: isEmoji
            ? const TextStyle(fontSize: 16)
            : const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: mainColor),
      ),
    );
    if (!review.avatarIsImage) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: review.avatar,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
