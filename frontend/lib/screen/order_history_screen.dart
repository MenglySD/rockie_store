import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/product_image.dart';
import 'package:rockie_store/models/order.dart';
import 'package:rockie_store/repositories/order_repository.dart';
import 'package:rockie_store/theme/app_colors.dart';
import 'package:rockie_store/screen/product_review_screen.dart';
import 'package:rockie_store/screen/purchase_order_detail_screen.dart';

/// GET /orders (paginated, infinite scroll). Tabs filter by status.
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final Set<int> _reviewedProducts = {};

  final List<Order> _orders = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<OrderRepository>().list(page: 1);
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(page.items);
        _page = page.currentPage;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await context.read<OrderRepository>().list(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _orders.addAll(page.items);
        _page = page.currentPage;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (mounted) showApiError(context, error, onRetry: _loadMore);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  ),
                  const Text(
                    'Order History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEDEBF0)),
            TabBar(
              controller: _tabs,
              indicatorColor: mainColor,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: mainColor,
              unselectedLabelColor: const Color(0xFF574A46),
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
            const Divider(height: 1, color: Color(0xFFF2B09B)),
            Expanded(
              child: _loading && _orders.isEmpty
                  ? const LoadingView()
                  : _error != null && _orders.isEmpty
                  ? ErrorView(error: _error!, onRetry: _load)
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _orderList(_orders, emptyMessage: 'No orders yet.'),
                        _orderList(
                          _orders.where((o) => o.isDelivered).toList(),
                          completed: true,
                          emptyMessage: 'No completed orders yet.',
                        ),
                        _orderList(
                          _orders.where((o) => o.isCancelled).toList(),
                          emptyMessage: 'No cancelled orders.',
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderList(
    List<Order> orders, {
    bool completed = false,
    required String emptyMessage,
  }) {
    return RefreshIndicator(
      color: mainColor,
      onRefresh: _load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 300) {
            _loadMore();
          }
          return false;
        },
        child: orders.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(emptyMessage, style: const TextStyle(color: Colors.black54))),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                itemCount: orders.length + (_loadingMore ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  if (index >= orders.length) {
                    return const Center(child: CircularProgressIndicator(color: mainColor));
                  }
                  final order = orders[index];
                  final first = order.items.isEmpty ? null : order.items.first;
                  return _OrderCard(
                    order: order,
                    completed: completed,
                    reviewed: first?.productId != null && _reviewedProducts.contains(first!.productId),
                    onReviewed: () {
                      if (first?.productId != null) {
                        setState(() => _reviewedProducts.add(first!.productId!));
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final bool completed;
  final bool reviewed;
  final VoidCallback onReviewed;

  const _OrderCard({required this.order, required this.completed, required this.reviewed, required this.onReviewed});

  @override
  Widget build(BuildContext context) {
    final first = order.items.isEmpty ? null : order.items.first;
    final others = order.items.length - 1;
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PurchaseOrderDetailScreen(orderId: order.id, initial: order),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFF2B09B)),
          boxShadow: const [
            BoxShadow(color: Color(0x09000000), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'ORDER #${order.number}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .25,
                    color: Color(0xFF66544E),
                  ),
                ),
                const Spacer(),
                Text(
                  order.statusLabel,
                  style: const TextStyle(fontSize: 11, color: mainColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: productImage(first?.imageUrl, width: 80, height: 80),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(first?.title ?? 'Order', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 7),
                        Text(
                          others > 0 ? 'Qty: ${order.itemCount} · +$others more' : 'Qty: ${order.itemCount}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6A625F)),
                        ),
                        const Spacer(),
                        Text(order.grandTotal.format(), style: const TextStyle(fontSize: 20, color: mainColor, height: 1)),
                      ],
                    ),
                  ),
                ),
                if (completed && first?.productId != null) ...[
                  const SizedBox(width: 8),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: SizedBox(
                        height: 33,
                        child: ElevatedButton(
                        onPressed: reviewed
                            ? null
                            : () async {
                                final submitted = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => ProductReviewScreen(
                                      productId: first!.productId!,
                                      productTitle: first.title,
                                    ),
                                  ),
                                );
                                if (submitted == true && context.mounted) {
                                  onReviewed();
                                }
                              },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          child: Text(reviewed ? 'Reviewed' : 'Review'),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
