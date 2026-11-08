import 'package:rockie_store/models/address.dart';
import 'package:rockie_store/models/json.dart';
import 'package:rockie_store/services/api_client.dart';

class AddressRepository {
  final ApiClient _api;
  AddressRepository(this._api);

  Future<List<Address>> list() async {
    final body = await _api.get('/addresses');
    return asList(asMap(body)['data'], Address.fromJson);
  }

  Future<Address> create(AddressInput input) async {
    final body = await _api.post('/addresses', data: input.toJson());
    return Address.fromJson(asMap(asMap(body)['data']));
  }

  Future<Address> update(int id, AddressInput input) async {
    final body = await _api.patch('/addresses/$id', data: input.toJson());
    return Address.fromJson(asMap(asMap(body)['data']));
  }

  /// Only sends `is_default: true`; the server unsets the user's other addresses.
  Future<Address> setDefault(int id) async {
    final body = await _api.patch('/addresses/$id', data: {'is_default': true});
    return Address.fromJson(asMap(asMap(body)['data']));
  }

  Future<void> delete(int id) => _api.delete('/addresses/$id');
}
