import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/product_image.dart';
import 'package:rockie_store/models/money.dart';
import 'package:rockie_store/models/order.dart';
import 'package:rockie_store/repositories/order_repository.dart';
import 'package:rockie_store/screen/product_detail_screen.dart';
import 'package:rockie_store/screen/track_order_screen.dart';
import 'package:rockie_store/theme/app_colors.dart';

/// GET /orders/{id}: status, address, items and server totals.
class PurchaseOrderDetailScreen extends StatefulWidget {
  final int orderId;

  /// Shown immediately while the latest status loads.
  final Order? initial;

  const PurchaseOrderDetailScreen({super.key, required this.orderId, this.initial});

  @override
  State<PurchaseOrderDetailScreen> createState() => _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  Order? _order;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _order = widget.initial;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await context.read<OrderRepository>().get(widget.orderId);
      if (mounted) setState(() => _order = order);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7FC),
        title: const Text('Order Details'),
      ),
      body: order == null
          ? (_loading ? const LoadingView() : ErrorView(error: _error ?? 'Not found', onRetry: _load))
          : RefreshIndicator(
              color: mainColor,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Order #${order.number}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            _StatusChip(order: order),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${order.paymentMethodLabel} · ${order.paymentStatusLabel} · ${_date(order.placedAt)}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        if (!order.isCancelled && !order.isDelivered) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Estimated delivery: ${order.estimatedDelivery}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text('Total: ${order.grandTotal.format()}', style: const TextStyle(color: mainColor, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Shipping address', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                          '${order.shippingAddress.recipientName}${order.shippingAddress.label == null ? '' : ' • ${order.shippingAddress.label}'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(order.shippingAddress.details, style: const TextStyle(color: Colors.black54, height: 1.4)),
                        Text(order.shippingAddress.phone, style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final line in order.items)
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFF0EDEA)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: productImage(line.imageUrl, width: 60, height: 60),
                        ),
                        title: Text(line.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${line.variant} · Qty: ${line.quantity} · ${line.lineTotal.format()}'),
                        trailing: line.productId == null ? null : const Icon(Icons.chevron_right),
                        onTap: line.productId == null
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen.id(line.productId!),
                                ),
                              ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration,
                    child: Column(
                      children: [
                        _row('Subtotal', order.subtotal),
                        const SizedBox(height: 6),
                        _row('Shipping (${order.deliveryMethod})', order.shippingTotal),
                        const SizedBox(height: 6),
                        _row(order.couponCode == null ? 'Discount' : 'Discount (${order.couponCode})', order.discountTotal, negative: true),
                        const Divider(height: 20),
                        _row('Total', order.grandTotal, bold: true),
                      ],
                    ),
                  ),
                  if (!order.isCancelled) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TrackOrderScreen(order: order)),
                      ),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Track Order'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: mainColor,
                        side: const BorderSide(color: mainColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _row(String label, Money value, {bool negative = false, bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? mainColor : Colors.black87);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        Text(negative && !value.isZero ? '-${value.format()}' : value.format(), style: style),
      ],
    );
  }

  String _date(DateTime? date) => date == null
      ? ''
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static final _cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
  );
}

class _StatusChip extends StatelessWidget {
  final Order order;
  const _StatusChip({required this.order});

  @override
  Widget build(BuildContext context) {
    final color = order.isCancelled
        ? Colors.grey
        : order.isDelivered
        ? const Color(0xFF2E9E5B)
        : mainColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
      child: Text(order.statusLabel, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
