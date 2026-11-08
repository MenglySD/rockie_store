import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rockie_store/models/cart.dart';
import 'package:rockie_store/models/money.dart';
import 'package:rockie_store/models/product.dart';
import 'package:rockie_store/models/review.dart';
import 'package:rockie_store/services/api_exception.dart';

void main() {
  group('Money', () {
    test('parses API decimal strings without floating point', () {
      expect(Money.parse('25.00').cents, 2500);
      expect(Money.parse('33.33').cents, 3333);
      expect(Money.parse('0.5').cents, 50);
      expect(Money.parse('-5.00').cents, -500);
      expect(Money.parse(null), Money.zero);
      expect(Money.parse('abc'), Money.zero);
    });

    test('formats for display', () {
      expect(Money.parse('25').format(), '\$25.00');
      expect(Money.parse('1.49').format(), '\$1.49');
      expect(const Money(-350).format(), '-\$3.50');
    });
  });

  test('formats sold_count like the old "70+" labels', () {
    expect(formatSoldCount(0), '0');
    expect(formatSoldCount(70), '70+');
    expect(formatSoldCount(1200), '1.2k+');
    expect(formatSoldCount(3000), '3k+');
  });

  test('Product.fromJson reads list and detail payloads', () {
    final listItem = Product.fromJson({
      'id': 1,
      'title': 'Loafers ',
      'price': '25.00',
      'original_price': '33.33',
      'discount_percent': 25,
      'sold_count': 70,
      'rating': 4.5,
      'review_count': 214,
      'image_url': 'http://x/a.jpg',
      'in_stock': true,
    });
    expect(listItem.title, 'Loafers');
    expect(listItem.images, ['http://x/a.jpg']);
    expect(listItem.sold, '70+');
    expect(listItem.hasDiscount, isTrue);

    final detail = Product.fromJson({
      'id': 1,
      'title': 'Loafers',
      'price': '25.00',
      'original_price': '25.00',
      'images': ['http://x/a.jpg', 'http://x/b.jpg'],
      'colors': ['Black'],
      'sizes': ['39', '40'],
      'variants': [
        {'id': 7, 'sku': 'RS-1', 'color': 'Black', 'size': '40', 'stock': 3, 'purchase_limit': 10},
      ],
      'review_summary': {
        'latest': [
          {'id': 1, 'name': 'Banana', 'avatar': '🍌', 'rating': 5, 'body': 'Nice', 'images': []},
        ],
      },
    });
    expect(detail.variantFor(color: 'Black', size: '40')?.id, 7);
    expect(detail.variantFor(color: 'Black', size: '39'), isNull);
    expect(detail.variants.single.maxQuantity, 3);
    expect(detail.reviews.single.name, 'Banana');
    expect(detail.hasDiscount, isFalse);
  });

  test('Review avatar: photo URL, sample emoji, or the name initial', () {
    final photo = Review.fromJson({'name': 'Mengly', 'avatar': 'http://x/storage/avatars/a.jpg'});
    expect(photo.avatarIsImage, isTrue);

    final emoji = Review.fromJson({'name': 'Banana', 'avatar': '🍌'});
    expect(emoji.avatarIsImage, isFalse);
    expect(emoji.avatar, '🍌');

    final none = Review.fromJson({'name': 'sokha', 'avatar': null});
    expect(none.avatar, isEmpty);
    expect(none.initial, 'S');
  });

  test('Cart.fromJson keeps server totals', () {
    final cart = Cart.fromJson({
      'id': 3,
      'items': [
        {
          'id': 91, 'product_id': 1, 'product_variant_id': 1, 'title': 'Loafers',
          'variant': 'Black / 39', 'unit_price': '25.00', 'quantity': 2,
          'line_total': '50.00', 'stock': 1, 'purchase_limit': 10, 'issue': 'insufficient_stock',
        },
      ],
      'item_count': 2,
      'coupon': {'code': 'WELCOME10', 'title': '10% OFF', 'is_applicable': true, 'message': null},
      'subtotal': '50.00',
      'discount_total': '5.00',
      'shipping_total': '1.49',
      'grand_total': '46.49',
    });
    expect(cart.grandTotal.format(), '\$46.49');
    expect(cart.coupon?.code, 'WELCOME10');
    expect(cart.hasIssues, isTrue);
    expect(cart.items.single.issueMessage, 'Only 1 left in stock');
    expect(cart.allSelected, isTrue);

    // An unselected item is not ordered, so its problem does not block checkout.
    final unselected = Cart.fromJson({
      'items': [
        {'id': 91, 'quantity': 2, 'stock': 1, 'issue': 'insufficient_stock', 'is_selected': false},
        {'id': 92, 'quantity': 1, 'stock': 5, 'is_selected': true},
      ],
      'item_count': 3,
      'selected_item_count': 1,
    });
    expect(unselected.selectedItems.single.id, 92);
    expect(unselected.selectedItemCount, 1);
    expect(unselected.hasSelection, isTrue);
    expect(unselected.allSelected, isFalse);
    expect(unselected.hasIssues, isFalse);
  });

  group('ApiException', () {
    DioException response(int status, Map<String, dynamic> body) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: status, data: body),
    );

    test('maps Laravel 422 errors to fields', () {
      final error = ApiException.fromDio(response(422, {
        'message': 'The email has already been taken. (and 1 more error)',
        'errors': {
          'email': ['The email has already been taken.'],
          'password': ['The password field must be at least 8 characters.'],
        },
      }));
      expect(error.isValidation, isTrue);
      expect(error.fieldError('email'), 'The email has already been taken.');
      expect(error.message, 'The email has already been taken.');
    });

    test('maps 409 with details and 401', () {
      final conflict = ApiException.fromDio(response(409, {
        'message': 'Only 3 left in stock.',
        'errors': {'available': 3},
      }));
      expect(conflict.isConflict, isTrue);
      expect(conflict.message, 'Only 3 left in stock.');
      expect((conflict.details as Map)['available'], 3);

      expect(ApiException.fromDio(response(401, {'message': 'Unauthenticated.'})).isUnauthorized, isTrue);
    });

    test('network errors are retryable', () {
      final error = ApiException.fromDio(
        DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError),
      );
      expect(error.type, ApiErrorType.network);
      expect(error.isRetryable, isTrue);
    });
  });
}
