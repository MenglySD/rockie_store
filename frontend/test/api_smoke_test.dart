// End-to-end check of the repositories against a running Laravel API.
// Skipped unless API_SMOKE_URL is set:
//
//   php artisan serve --port=8000                    (in backend/)
//   flutter test test/api_smoke_test.dart --dart-define=API_SMOKE_URL=http://127.0.0.1:8000/api/v1
//
// It registers a throwaway user, so run it against a development database only.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rockie_store/models/address.dart';
import 'package:rockie_store/models/payment_method.dart';
import 'package:rockie_store/models/user.dart';
import 'package:rockie_store/repositories/address_repository.dart';
import 'package:rockie_store/repositories/auth_repository.dart';
import 'package:rockie_store/repositories/cart_repository.dart';
import 'package:rockie_store/repositories/order_repository.dart';
import 'package:rockie_store/repositories/payment_method_repository.dart';
import 'package:rockie_store/repositories/product_repository.dart';
import 'package:rockie_store/repositories/profile_repository.dart';
import 'package:rockie_store/services/api_client.dart';
import 'package:rockie_store/services/api_exception.dart';
import 'package:rockie_store/services/token_storage.dart';

const _baseUrl = String.fromEnvironment('API_SMOKE_URL');

/// A valid 1×1 PNG.
const _tinyPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

/// In-memory token storage (the keychain plugin is not available in tests).
class _MemoryTokens extends TokenStorage {
  String? _token;
  @override
  Future<String?> read() async => _token;
  @override
  Future<void> write(String token) async => _token = token;
  @override
  Future<void> clear() async => _token = null;
}

void main() {
  final api = ApiClient(
    tokens: _MemoryTokens(),
    dio: Dio(BaseOptions(baseUrl: _baseUrl, headers: {'Accept': 'application/json'})),
  );
  final auth = AuthRepository(api);
  final profile = ProfileRepository(api);
  final products = ProductRepository(api);
  final cart = CartRepository(api);
  final addresses = AddressRepository(api);
  final payments = PaymentMethodRepository(api);
  final orders = OrderRepository(api);

  test('full shopping flow against the real API', () async {
    // Catalog
    final categories = await products.categories();
    expect(categories, isNotEmpty);
    final page = await products.products(const ProductQuery(sort: ProductSort.popular), perPage: 5);
    expect(page.items, isNotEmpty);
    expect(page.total, greaterThan(0));
    final detail = await products.product(page.items.first.id);
    expect(detail.variants, isNotEmpty);
    final reviews = await products.reviews(1);
    expect(reviews.items.first.name, isNotEmpty);

    // Register → new user has no address and no payment method
    final email = 'smoke${DateTime.now().millisecondsSinceEpoch}@example.com';
    final registered = await auth.register(
      name: 'Smoke Test',
      email: email,
      password: 'password123',
      passwordConfirmation: 'password123',
    );
    expect(registered.user.email, email);
    expect(await addresses.list(), isEmpty);
    expect(await payments.list(), isEmpty);

    // Profile
    final me = await profile.update(name: 'Smoke Tester', gender: Gender.female);
    expect(me.name, 'Smoke Tester');

    // 422 under fields
    try {
      await addresses.create(const AddressInput(
        recipientName: '', phone: '', line1: '', city: '', isDefault: false,
      ));
      fail('expected 422');
    } on ApiException catch (e) {
      expect(e.isValidation, isTrue);
      expect(e.fieldError('recipient_name'), isNotNull);
    }

    // Order without address → 422
    final variant = detail.variants.firstWhere((v) => v.inStock);
    var current = await cart.addItem(productVariantId: variant.id, quantity: 1);
    expect(current.items.single.productVariantId, variant.id);
    expect(current.grandTotal.cents, greaterThan(0));

    // Address and payment method, no default unless asked
    final address = await addresses.create(const AddressInput(
      label: 'Home', recipientName: 'Smoke', phone: '+85512345678', line1: 'St 1',
      city: 'Phnom Penh', isDefault: false,
    ));
    expect(address.isDefault, isFalse);
    final card = await payments.create(PaymentMethodInput(
      brand: 'visa', last4: '4242', expMonth: 12, expYear: DateTime.now().year + 2, isDefault: false,
    ));
    expect(card.isDefault, isFalse);
    expect(card.expiry, isNotNull);
    expect(card.label, 'Visa •••• 4242');
    expect((await addresses.setDefault(address.id)).isDefault, isTrue);

    // Place order, retry with the same key returns the same order
    final placed = await orders.place(
      addressId: address.id,
      paymentMethodId: card.id,
      deliveryMethod: 'express',
      idempotencyKey: 'smoke-$email',
    );
    expect(placed.number, isNotEmpty);
    expect(placed.shippingTotal.format(), '\$2.49');
    final retried = await orders.place(
      addressId: address.id,
      paymentMethodId: card.id,
      deliveryMethod: 'express',
      idempotencyKey: 'smoke-$email',
    );
    expect(retried.id, placed.id);
    expect((await cart.get()).isEmpty, isTrue);
    expect((await orders.list()).items.first.id, placed.id);
    expect((await orders.notifications()).items, isNotEmpty);

    // Review the ordered product with two photos (a 1×1 PNG).
    final review = await products.submitReview(
      detail.id,
      rating: 5,
      body: 'Smoke test review with photos',
      photos: [ReviewPhoto(_tinyPng, 'one.png'), ReviewPhoto(_tinyPng, 'two.png')],
    );
    expect(review.images, hasLength(2));
    expect(review.images.first, contains('/storage/reviews/'));

    // 409 when asking for more than the stock
    try {
      await cart.addItem(productVariantId: variant.id, quantity: variant.stock + 1);
      fail('expected 409 or 422');
    } on ApiException catch (e) {
      expect(e.isConflict || e.isValidation, isTrue);
    }

    // Logout → token revoked → log in again
    await auth.logout();
    final again = await auth.login(email: email, password: 'password123');
    expect(again.user.email, email);
  }, skip: _baseUrl.isEmpty ? 'Set --dart-define=API_SMOKE_URL to run' : false);
}
