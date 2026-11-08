import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/product_image.dart';
import 'package:rockie_store/models/order.dart';
import 'package:rockie_store/repositories/order_repository.dart';
import 'package:rockie_store/screen/purchase_order_detail_screen.dart';
import 'package:rockie_store/screen/track_order_screen.dart';
import 'package:rockie_store/theme/app_colors.dart';

/// "To Pay" = card payment awaiting confirmation, "To Ship" = placed or
/// processing, "To Receive" = shipped.
enum OrderStatus { toPay, toShip, toReceive }

class OrderStatusScreen extends StatefulWidget {
  final OrderStatus status;

  const OrderStatusScreen({super.key, required this.status});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  List<Order> _orders = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<OrderRepository>().list(perPage: 50);
      if (mounted) setState(() => _orders = page.items.where(_matches).toList());
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matches(Order order) => switch (widget.status) {
    OrderStatus.toPay => order.isAwaitingPayment,
    OrderStatus.toShip => order.isToShip,
    OrderStatus.toReceive => order.isToReceive,
  };

  String get _title => switch (widget.status) {
    OrderStatus.toPay => 'To Pay',
    OrderStatus.toShip => 'To Ship',
    OrderStatus.toReceive => 'To Receive',
  };

  IconData get _icon => switch (widget.status) {
    OrderStatus.toPay => Icons.payments_outlined,
    OrderStatus.toShip => Icons.inventory_2_outlined,
    OrderStatus.toReceive => Icons.local_shipping_outlined,
  };

  void _onAction(Order order) {
    if (widget.status == OrderStatus.toReceive) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TrackOrderScreen(order: order)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PurchaseOrderDetailScreen(orderId: order.id, initial: order),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7FC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading && _orders.isEmpty
          ? const LoadingView()
          : _error != null && _orders.isEmpty
          ? ErrorView(error: _error!, onRetry: _load)
          : RefreshIndicator(
              color: mainColor,
              onRefresh: _load,
              child: _orders.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 160),
                        Center(child: Text('No ${_title.toLowerCase()} orders yet.')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      itemCount: _orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) => _StatusOrderCard(
                        order: _orders[index],
                        icon: _icon,
                        action: widget.status == OrderStatus.toReceive ? 'Track Order' : 'View Details',
                        onAction: () => _onAction(_orders[index]),
                      ),
                    ),
            ),
    );
  }
}

class _StatusOrderCard extends StatelessWidget {
  final Order order;
  final IconData icon;
  final String action;
  final VoidCallback onAction;

  const _StatusOrderCard({
    required this.order,
    required this.icon,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final first = order.items.isEmpty ? null : order.items.first;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF2B09B)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 16,
                color: Color(0xFF806D67),
              ),
              const SizedBox(width: 7),
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
                order.paymentStatusLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: mainColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: productImage(first?.imageUrl, width: 76, height: 76),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first?.title ?? 'Order',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Qty: ${order.itemCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6A625F),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      order.grandTotal.format(),
                      style: const TextStyle(fontSize: 18, color: mainColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Divider(height: 1, color: Color(0xFFF0EDEA)),
          const SizedBox(height: 11),
          Row(
            children: [
              Icon(icon, size: 16, color: mainColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.statusLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF625C59),
                  ),
                ),
              ),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(action),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
