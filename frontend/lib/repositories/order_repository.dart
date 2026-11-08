import 'package:rockie_store/models/json.dart';
import 'package:rockie_store/models/notification.dart';
import 'package:rockie_store/models/order.dart';
import 'package:rockie_store/models/paginated.dart';
import 'package:rockie_store/services/api_client.dart';

class OrderRepository {
  final ApiClient _api;
  OrderRepository(this._api);

  /// Places an order from the server cart. Reuse the same [idempotencyKey]
  /// when retrying so a slow network never creates two orders.
  Future<Order> place({
    required int addressId,
    required int paymentMethodId,
    required String deliveryMethod,
    required String idempotencyKey,
    String? note,
  }) async {
    final body = await _api.post(
      '/orders',
      data: {
        'address_id': addressId,
        'payment_method_id': paymentMethodId,
        'delivery_method': deliveryMethod,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return Order.fromJson(asMap(asMap(body)['data']));
  }

  Future<Paginated<Order>> list({int page = 1, int perPage = 20}) async {
    final body = await _api.get('/orders', query: {'page': page, 'per_page': perPage});
    return Paginated.fromJson(asMap(body), Order.fromJson);
  }

  Future<Order> get(int id) async {
    final body = await _api.get('/orders/$id');
    return Order.fromJson(asMap(asMap(body)['data']));
  }

  // ---- Notifications ----

  Future<Paginated<NotificationItem>> notifications({int page = 1}) async {
    final body = await _api.get('/notifications', query: {'page': page});
    return Paginated.fromJson(asMap(body), NotificationItem.fromJson);
  }

  Future<void> markNotificationRead(int id) => _api.post('/notifications/$id/read');

  Future<void> markAllNotificationsRead() => _api.post('/notifications/read-all');
}
