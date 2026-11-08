import 'package:rockie_store/models/json.dart';
import 'package:rockie_store/models/money.dart';

/// One line of the server cart. Prices and totals are calculated by Laravel.
class CartItem {
  final int id;
  final int productId;
  final int productVariantId;
  final String title;
  final String variant;
  final String? color;
  final String? size;
  final Money unitPrice;
  final Money originalPrice;
  final int quantity;

  /// Only selected items count towards the totals and are ordered.
  final bool isSelected;
  final Money lineTotal;
  final String? imageUrl;
  final int stock;
  final int purchaseLimit;

  /// null, "unavailable", "insufficient_stock" or "over_purchase_limit".
  final String? issue;

  const CartItem({
    required this.id,
    required this.productId,
    required this.productVariantId,
    required this.title,
    required this.variant,
    this.color,
    this.size,
    required this.unitPrice,
    required this.originalPrice,
    required this.quantity,
    this.isSelected = true,
    required this.lineTotal,
    this.imageUrl,
    required this.stock,
    required this.purchaseLimit,
    this.issue,
  });

  int get maxQuantity => stock < purchaseLimit ? stock : purchaseLimit;

  String? get issueMessage => switch (issue) {
    'unavailable' => 'No longer available',
    'insufficient_stock' => stock > 0 ? 'Only $stock left in stock' : 'Out of stock',
    'over_purchase_limit' => 'Limit $purchaseLimit per order',
    _ => null,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: asInt(json['id']),
    productId: asInt(json['product_id']),
    productVariantId: asInt(json['product_variant_id']),
    title: asString(json['title']),
    variant: asString(json['variant']),
    color: asStringOrNull(json['color']),
    size: asStringOrNull(json['size']),
    unitPrice: Money.parse(json['unit_price']),
    originalPrice: Money.parse(json['original_price']),
    quantity: asInt(json['quantity'], 1),
    isSelected: asBool(json['is_selected'], true),
    lineTotal: Money.parse(json['line_total']),
    imageUrl: asStringOrNull(json['image_url']),
    stock: asInt(json['stock']),
    purchaseLimit: asInt(json['purchase_limit'], 10),
    issue: asStringOrNull(json['issue']),
  );
}

class CartCoupon {
  final String code;
  final String title;
  final bool isApplicable;
  final String? message;

  const CartCoupon({
    required this.code,
    required this.title,
    required this.isApplicable,
    this.message,
  });

  factory CartCoupon.fromJson(Map<String, dynamic> json) => CartCoupon(
    code: asString(json['code']),
    title: asString(json['title']),
    isApplicable: asBool(json['is_applicable'], true),
    message: asStringOrNull(json['message']),
  );
}

class Cart {
  final int id;
  final List<CartItem> items;

  /// Quantity of every item (cart badge).
  final int itemCount;

  /// Quantity of the selected items (what checkout orders).
  final int selectedItemCount;
  final CartCoupon? coupon;
  final String deliveryMethod;
  final Money subtotal;
  final Money discountTotal;
  final Money shippingTotal;
  final Money grandTotal;
  final String currency;

  const Cart({
    required this.id,
    required this.items,
    required this.itemCount,
    this.selectedItemCount = 0,
    this.coupon,
    this.deliveryMethod = 'standard',
    required this.subtotal,
    required this.discountTotal,
    required this.shippingTotal,
    required this.grandTotal,
    this.currency = 'USD',
  });

  static const empty = Cart(
    id: 0,
    items: [],
    itemCount: 0,
    subtotal: Money.zero,
    discountTotal: Money.zero,
    shippingTotal: Money.zero,
    grandTotal: Money.zero,
  );

  bool get isEmpty => items.isEmpty;

  List<CartItem> get selectedItems => [for (final item in items) if (item.isSelected) item];
  bool get hasSelection => items.any((item) => item.isSelected);
  bool get allSelected => items.isNotEmpty && items.every((item) => item.isSelected);

  /// Only selected items block checkout.
  bool get hasIssues => items.any((item) => item.isSelected && item.issue != null);

  factory Cart.fromJson(Map<String, dynamic> json) {
    final coupon = json['coupon'];
    return Cart(
      id: asInt(json['id']),
      items: asList(json['items'], CartItem.fromJson),
      itemCount: asInt(json['item_count']),
      selectedItemCount: asInt(json['selected_item_count'], asInt(json['item_count'])),
      coupon: coupon is Map ? CartCoupon.fromJson(Map<String, dynamic>.from(coupon)) : null,
      deliveryMethod: asString(json['delivery_method'], 'standard'),
      subtotal: Money.parse(json['subtotal']),
      discountTotal: Money.parse(json['discount_total']),
      shippingTotal: Money.parse(json['shipping_total']),
      grandTotal: Money.parse(json['grand_total']),
      currency: asString(json['currency'], 'USD'),
    );
  }
}
