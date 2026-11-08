import 'package:rockie_store/models/json.dart';
import 'package:rockie_store/models/payment_method.dart';
import 'package:rockie_store/services/api_client.dart';

class PaymentMethodRepository {
  final ApiClient _api;
  PaymentMethodRepository(this._api);

  Future<List<PaymentMethod>> list() async {
    final body = await _api.get('/payment-methods');
    return asList(asMap(body)['data'], PaymentMethod.fromJson);
  }

  Future<PaymentMethod> create(PaymentMethodInput input) async {
    final body = await _api.post('/payment-methods', data: input.toJson());
    return PaymentMethod.fromJson(asMap(asMap(body)['data']));
  }

  Future<PaymentMethod> setDefault(int id) async {
    final body = await _api.patch('/payment-methods/$id', data: {'is_default': true});
    return PaymentMethod.fromJson(asMap(asMap(body)['data']));
  }

  Future<void> delete(int id) => _api.delete('/payment-methods/$id');
}
