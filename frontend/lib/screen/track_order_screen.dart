import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/product_image.dart';
import 'package:rockie_store/models/order.dart';
import 'package:rockie_store/repositories/order_repository.dart';

/// Tracking timeline for one order. Shows [order] straight away, then
/// reloads it from GET /orders/{id}; pull down to refresh.
///
/// Steps: Order Placed → Processing → Shipped → Out for Delivery → Delivered.
/// Finished steps show when they happened, the current step is highlighted,
/// later steps are greyed out.
class TrackOrderScreen extends StatefulWidget {
  final Order order;

  const TrackOrderScreen({super.key, required this.order});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  static const _orange = Color(0xFFFF4D00);
  static const _background = Color(0xFFF8F7FC);
  static const _border = Color(0xFFF2E2E6);
  static const _ink = Color(0xFF172033);
  static const _muted = Color(0xFF77737A);
  static const _pale = Color(0xFFE5BEB5);
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  late Order _order = widget.order;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final order = await context.read<OrderRepository>().get(_order.id);
      if (mounted) setState(() => _order = order);
    } catch (error) {
      if (mounted) showApiError(context, error, onRetry: _refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text('Track My Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: _orange,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _card(child: _summary()),
                    const SizedBox(height: 16),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tracking Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
                          const SizedBox(height: 22),
                          _timeline(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _card(child: _items()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ORDER ID on the left; estimated (or actual) delivery on the right.
  Widget _summary() {
    final order = _order;
    final (String label, String value, Color color) = order.isCancelled
        ? ('STATUS', 'Cancelled', _muted)
        : order.isDelivered
        ? ('DELIVERED', _date(order.deliveredAt) ?? order.estimatedDelivery, _orange)
        : ('EST. DELIVERY', order.estimatedDelivery, _orange);
    return Row(
      children: [
        Expanded(child: _orderDetail('ORDER ID', '#${order.number}')),
        const SizedBox(width: 12),
        _orderDetail(label, value, alignEnd: true, color: color),
      ],
    );
  }

  Widget _orderDetail(String label, String value, {bool alignEnd = false, Color color = _ink}) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF68636A), letterSpacing: .3)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _timeline() {
    final order = _order;
    final steps = <_Step>[
      _Step('Order Placed', order.placedAt, order.isAwaitingPayment ? 'Waiting for payment' : 'We received your order'),
      if (order.isCancelled)
        _Step('Cancelled', order.cancelledAt, 'This order was cancelled')
      else ...[
        _Step('Processing', order.processingAt ?? order.paidAt, 'Preparing to ship'),
        _Step('Shipped', order.shippedAt, 'On the way'),
        _Step('Out for Delivery', order.outForDeliveryAt, 'Arriving soon'),
        _Step('Delivered', order.deliveredAt, 'Enjoy your order!'),
      ],
    ];
    final current = order.isCancelled
        ? 1
        : switch (order.status) {
            'processing' => 1,
            'shipped' => 2,
            'out_for_delivery' => 3,
            'delivered' => 4,
            _ => 0,
          };

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _timelineRow(
            step: steps[i],
            state: i < current ? _StepState.done : i == current ? _StepState.current : _StepState.upcoming,
            isLast: i == steps.length - 1,
            // The line below a step is orange only up to the current step.
            lineDone: i < current,
          ),
      ],
    );
  }

  Widget _timelineRow({required _Step step, required _StepState state, required bool isLast, required bool lineDone}) {
    final isCurrent = state == _StepState.current;
    final time = _dateTime(step.time);

    final Widget dot = isCurrent
        ? Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _orange, width: 4),
              boxShadow: const [BoxShadow(color: Color(0x33FF4D00), spreadRadius: 3)],
            ),
          )
        : Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state == _StepState.done ? _orange : _pale,
            ),
          );

    final Widget content = isCurrent
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(color: const Color(0xFFFFF1EA), borderRadius: BorderRadius.circular(9)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: const TextStyle(color: _orange, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  time == null ? step.caption : '$time - ${step.caption}',
                  style: const TextStyle(color: _orange, fontSize: 12),
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: state == _StepState.done ? _ink : const Color(0xFF92909A),
                  ),
                ),
                if (state == _StepState.done && time != null) ...[
                  const SizedBox(height: 2),
                  Text(time, style: const TextStyle(fontSize: 12, color: _muted)),
                ],
              ],
            ),
          );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                SizedBox(height: isCurrent ? 8 : 4),
                dot,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: lineDone ? _orange : const Color(0xFFE9C8C1),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  Widget _items() {
    final items = _order.items;
    if (items.isEmpty) {
      return Text('${_order.itemCount} items', style: const TextStyle(fontSize: 14, color: _muted));
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 24, color: _border),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: productImage(items[i].imageUrl, width: 88, height: 88),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items[i].title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black, height: 1.4),
                    ),
                    const SizedBox(height: 4),
                    Text('Qty: ${items[i].quantity}', style: const TextStyle(fontSize: 12, color: _muted)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFAFF),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _border),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 9, offset: Offset(0, 3))],
        ),
        child: child,
      );

  /// "Oct 25, 2024"
  static String? _date(DateTime? time) =>
      time == null ? null : '${_months[time.month - 1]} ${time.day}, ${time.year}';

  /// "Oct 25, 10:45 AM"
  static String? _dateTime(DateTime? time) {
    if (time == null) return null;
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '${_months[time.month - 1]} ${time.day}, ${hour.toString().padLeft(2, '0')}:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
  }
}

enum _StepState { done, current, upcoming }

class _Step {
  final String title;
  final DateTime? time;

  /// Shown after the time while this is the current step, e.g. "Arriving soon".
  final String caption;

  const _Step(this.title, this.time, this.caption);
}
