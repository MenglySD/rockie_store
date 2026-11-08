import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/cart_view.dart';
import 'package:rockie_store/models/cart.dart';
import 'package:rockie_store/provider/cart_provider.dart';
import 'package:rockie_store/repositories/cart_repository.dart';
import 'package:rockie_store/services/api_client.dart';
import 'package:rockie_store/services/token_storage.dart';

/// In-memory cart standing in for the API.
class _FakeCartRepository extends CartRepository {
  _FakeCartRepository() : super(ApiClient(tokens: TokenStorage()));

  final List<Map<String, dynamic>> _items = [
    {'id': 1, 'title': 'Loafers', 'variant': 'Black / 40', 'unit_price': '25.00', 'quantity': 1, 'line_total': '25.00', 'stock': 5, 'is_selected': true},
    {'id': 2, 'title': 'Shirt', 'variant': 'White / M', 'unit_price': '10.00', 'quantity': 1, 'line_total': '10.00', 'stock': 5, 'is_selected': true},
  ];
  final List<int> removed = [];

  Cart get _cart => Cart.fromJson({'id': 1, 'items': _items, 'item_count': _items.length, 'selected_item_count': _items.length});

  @override
  Future<Cart> get({String deliveryMethod = 'standard'}) async => _cart;

  @override
  Future<Cart> updateItem(int itemId, int quantity) async {
    _items.firstWhere((item) => item['id'] == itemId)['quantity'] = quantity;
    return _cart;
  }

  @override
  Future<Cart> setItemSelected(int itemId, bool selected) async {
    _items.firstWhere((item) => item['id'] == itemId)['is_selected'] = selected;
    return _cart;
  }

  @override
  Future<Cart> removeItem(int itemId) async {
    removed.add(itemId);
    _items.removeWhere((item) => item['id'] == itemId);
    return _cart;
  }
}

void main() {
  testWidgets('swiping an item left and tapping Delete removes it', (tester) async {
    final repository = _FakeCartRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartProvider(repository),
        child: const MaterialApp(home: Scaffold(body: CartView())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Loafers'), findsOneWidget);

    // The Delete button is hidden (and not tappable) until the card is swiped.
    await tester.tap(find.text('Delete').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repository.removed, isEmpty);

    await tester.drag(find.text('Loafers'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();

    expect(repository.removed, [1]);
    expect(find.text('Loafers'), findsNothing);
    expect(find.text('Shirt'), findsOneWidget);
  });
}
