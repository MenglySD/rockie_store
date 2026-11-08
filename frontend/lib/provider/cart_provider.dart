import 'package:flutter/foundation.dart';
import 'package:rockie_store/models/cart.dart';
import 'package:rockie_store/repositories/cart_repository.dart';
import 'package:rockie_store/services/api_exception.dart';

/// The server cart. Replaces the old global `cartItems` list.
/// Totals are always the server's; the app never calculates prices.
class CartProvider extends ChangeNotifier {
  final CartRepository _repository;
  CartProvider(this._repository);

  Cart _cart = Cart.empty;
  Cart get cart => _cart;

  bool _loading = false;
  bool get loading => _loading;

  bool _loaded = false;
  bool get loaded => _loaded;

  /// True while an add/update/remove/coupon request is running.
  bool _busy = false;
  bool get busy => _busy;

  ApiException? _error;
  ApiException? get error => _error;

  String _deliveryMethod = 'standard';
  String get deliveryMethod => _deliveryMethod;

  int get itemCount => _cart.itemCount;

  Future<void> load({String? deliveryMethod}) async {
    if (deliveryMethod != null) _deliveryMethod = deliveryMethod;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _cart = await _repository.get(deliveryMethod: _deliveryMethod);
      _loaded = true;
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addItem({required int productVariantId, required int quantity}) =>
      _mutate(() => _repository.addItem(productVariantId: productVariantId, quantity: quantity));

  Future<void> updateQuantity(CartItem item, int quantity) =>
      _mutate(() => _repository.updateItem(item.id, quantity));

  Future<void> setSelected(CartItem item, bool selected) =>
      _mutate(() => _repository.setItemSelected(item.id, selected));

  Future<void> setAllSelected(bool selected) => _mutate(() => _repository.setAllSelected(selected));

  /// "Buy now": this product becomes the only selected item, so checkout
  /// orders just it. Other items stay in the cart, unselected.
  Future<void> buyNow({required int productVariantId, required int quantity}) => _mutate(() async {
    await _repository.setAllSelected(false);
    return _repository.addItem(productVariantId: productVariantId, quantity: quantity);
  });

  Future<void> removeItem(CartItem item) => _mutate(() => _repository.removeItem(item.id));

  Future<void> removeItems(Iterable<CartItem> items) => _mutate(() async {
    Cart? latest;
    for (final item in items) {
      latest = await _repository.removeItem(item.id);
    }
    return latest ?? await _repository.get(deliveryMethod: _deliveryMethod);
  });

  Future<void> applyCoupon(String code) => _mutate(() => _repository.applyCoupon(code));

  Future<void> removeCoupon() => _mutate(_repository.removeCoupon);

  /// Called after logout.
  void clear() {
    _cart = Cart.empty;
    _loaded = false;
    _error = null;
    _deliveryMethod = 'standard';
    notifyListeners();
  }

  /// Runs a cart change. On 409 (stock/coupon changed) the cart is reloaded
  /// before the error is rethrown so the screen shows the new state.
  Future<void> _mutate(Future<Cart> Function() request) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      _cart = await request();
      _loaded = true;
      _error = null;
      // Mutations return standard-shipping totals; re-read if express is selected.
      if (_deliveryMethod != 'standard') {
        _cart = await _repository.get(deliveryMethod: _deliveryMethod);
      }
    } on ApiException catch (e) {
      if (e.isConflict) {
        try {
          _cart = await _repository.get(deliveryMethod: _deliveryMethod);
        } catch (_) {}
      }
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
