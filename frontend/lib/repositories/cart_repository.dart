import 'package:rockie_store/models/cart.dart';
import 'package:rockie_store/models/coupon.dart';
import 'package:rockie_store/models/json.dart';
import 'package:rockie_store/services/api_client.dart';

/// Every call returns the full server cart with server-calculated totals.
class CartRepository {
  final ApiClient _api;
  CartRepository(this._api);

  Future<Cart> get({String deliveryMethod = 'standard'}) async =>
      _cart(await _api.get('/cart', query: {'delivery_method': deliveryMethod}));

  Future<Cart> addItem({required int productVariantId, required int quantity}) async =>
      _cart(await _api.post('/cart/items', data: {
        'product_variant_id': productVariantId,
        'quantity': quantity,
      }));

  Future<Cart> updateItem(int itemId, int quantity) async =>
      _cart(await _api.patch('/cart/items/$itemId', data: {'quantity': quantity}));

  Future<Cart> setItemSelected(int itemId, bool selected) async =>
      _cart(await _api.patch('/cart/items/$itemId', data: {'is_selected': selected}));

  /// Select or unselect every item.
  Future<Cart> setAllSelected(bool selected) async =>
      _cart(await _api.patch('/cart/selection', data: {'is_selected': selected}));

  Future<Cart> removeItem(int itemId) async => _cart(await _api.delete('/cart/items/$itemId'));

  Future<Cart> applyCoupon(String code) async =>
      _cart(await _api.post('/cart/coupon', data: {'code': code.trim()}));

  Future<Cart> removeCoupon() async => _cart(await _api.delete('/cart/coupon'));

  Future<List<Coupon>> coupons() async {
    final body = await _api.get('/coupons');
    return asList(asMap(body)['data'], Coupon.fromJson);
  }

  Cart _cart(dynamic body) => Cart.fromJson(asMap(asMap(body)['data']));
}
