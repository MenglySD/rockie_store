import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/models/order.dart';
import 'package:rockie_store/repositories/order_repository.dart';
import 'package:rockie_store/screen/track_order_screen.dart';
import 'package:rockie_store/services/api_client.dart';
import 'package:rockie_store/services/token_storage.dart';

/// Returns the given order instead of calling GET /orders/{id}.
class _FakeOrderRepository extends OrderRepository {
  final Order order;
  _FakeOrderRepository(this.order) : super(ApiClient(tokens: TokenStorage()));

  @override
  Future<Order> get(int id) async => order;
}

Order _order(Map<String, dynamic> overrides) => Order.fromJson({
  'id': 7,
  'number': 'RS261022-ABCDEF',
  'status': 'pending',
  'payment_status': 'pending',
  'payment_method': {'type': 'card', 'label': 'Visa •••• 4242'},
  'delivery_method': 'standard',
  'items': [
    {'id': 1, 'title': 'Slip-On Loafers', 'quantity': 2, 'unit_price': '25.00', 'line_total': '50.00'},
  ],
  // Local times (no "Z") so the expected text does not depend on the time zone.
  'placed_at': '2026-10-23T09:30:00',
  ...overrides,
});

Future<void> _show(WidgetTester tester, Order order) async {
  await tester.pumpWidget(
    Provider<OrderRepository>.value(
      value: _FakeOrderRepository(order),
      child: MaterialApp(home: TrackOrderScreen(order: order)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('out for delivery: earlier steps show their times, current step is highlighted', (tester) async {
    await _show(tester, _order({
      'status': 'out_for_delivery',
      'payment_status': 'paid',
      'paid_at': '2026-10-23T14:15:00',
      'processing_at': '2026-10-23T14:15:00',
      'shipped_at': '2026-10-24T08:00:00',
      'out_for_delivery_at': '2026-10-25T10:45:00',
    }));

    expect(find.text('#RS261022-ABCDEF'), findsOneWidget);
    expect(find.text('EST. DELIVERY'), findsOneWidget);
    expect(find.text('Oct 23, 09:30 AM'), findsOneWidget);
    expect(find.text('Oct 23, 02:15 PM'), findsOneWidget);
    expect(find.text('Oct 24, 08:00 AM'), findsOneWidget);
    expect(find.text('Oct 25, 10:45 AM - Arriving soon'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('Slip-On Loafers'), findsOneWidget);
    expect(find.text('Qty: 2'), findsOneWidget);
  });

  testWidgets('new card order waits for payment', (tester) async {
    await _show(tester, _order({}));

    expect(find.text('Oct 23, 09:30 AM - Waiting for payment'), findsOneWidget);
    for (final step in ['Processing', 'Shipped', 'Out for Delivery', 'Delivered']) {
      expect(find.text(step), findsOneWidget);
    }
  });

  testWidgets('cancelled order stops the timeline', (tester) async {
    await _show(tester, _order({'status': 'cancelled', 'cancelled_at': '2026-10-23T11:00:00'}));

    expect(find.text('Oct 23, 11:00 AM - This order was cancelled'), findsOneWidget);
    expect(find.text('Shipped'), findsNothing);
    expect(find.text('STATUS'), findsOneWidget);
  });
}
