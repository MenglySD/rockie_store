import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/models/order.dart';
import 'package:rockie_store/provider/home_provider.dart';
import 'package:rockie_store/screen/purchase_order_detail_screen.dart';
import 'package:rockie_store/screen/track_order_screen.dart';

/// Shown after POST /orders succeeds.
class OrderConfirmationScreen extends StatefulWidget {
  final Order order;

  const OrderConfirmationScreen({super.key, required this.order});

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  Order get order => widget.order;
  String get orderNumber => '#${order.number}';

  static const Color _primaryOrange = Color(0xFFFF4D00);
  static const Color _backgroundColor = Color(0xFFF8F9FA);

  Widget _detailRow(String label, String value, {Color valueColor = Colors.black}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCard = order.paymentMethodType == 'card';
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24),
          child: Column(
            children: [
              // Success Checkmark Badge
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFECE5),
                ),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _primaryOrange,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 54,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Success Messages
              const Text(
                'Order Placed!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isCard
                    ? 'Your order has been placed. We\'ll confirm\nonce your card payment is approved.'
                    : 'Your order has been confirmed. We\'ll send\nyou a tracking update shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Order Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _detailRow('Order Number', orderNumber, valueColor: _primaryOrange),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    _detailRow('Status', order.statusLabel),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    _detailRow('Estimated Delivery', order.estimatedDelivery),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    _detailRow('Payment', '${order.paymentMethodLabel} · ${order.paymentStatusLabel}'),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    _detailRow(isCard ? 'Total' : 'Total to pay', order.grandTotal.format()),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryOrange,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TrackOrderScreen(order: order)),
                  ),
                  child: const Text(
                    'Track My Order',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _primaryOrange, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PurchaseOrderDetailScreen(orderId: order.id, initial: order),
                    ),
                  ),
                  child: const Text(
                    'View Order Details',
                    style: TextStyle(
                      fontSize: 16,
                      color: _primaryOrange,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  context.read<HomeProvider>().onTap(0);
                  Navigator.of(context, rootNavigator: true)
                      .popUntil((route) => route.isFirst);
                },
                child: const Text(
                  'Continue Shopping',
                  style: TextStyle(fontSize: 15, color: _primaryOrange),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
