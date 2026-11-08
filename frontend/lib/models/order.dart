import 'package:rockie_store/models/json.dart';
import 'package:rockie_store/models/money.dart';

class OrderItem {
  final int id;
  final int? productId;
  final int? productVariantId;
  final String title;
  final String sku;
  final String variant;
  final String? imageUrl;
  final Money unitPrice;
  final int quantity;
  final Money lineTotal;

  const OrderItem({
    required this.id,
    this.productId,
    this.productVariantId,
    required this.title,
    required this.sku,
    required this.variant,
    this.imageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: asInt(json['id']),
    productId: asIntOrNull(json['product_id']),
    productVariantId: asIntOrNull(json['product_variant_id']),
    title: asString(json['title']),
    sku: asString(json['sku']),
    variant: asString(json['variant']),
    imageUrl: asStringOrNull(json['image_url']),
    unitPrice: Money.parse(json['unit_price']),
    quantity: asInt(json['quantity'], 1),
    lineTotal: Money.parse(json['line_total']),
  );
}

class ShippingAddress {
  final String? label;
  final String recipientName;
  final String phone;
  final String details;

  const ShippingAddress({
    this.label,
    required this.recipientName,
    required this.phone,
    required this.details,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    String? part(String key) {
      final value = json[key]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    return ShippingAddress(
      label: part('label'),
      recipientName: asString(json['recipient_name']),
      phone: asString(json['phone']),
      details: [
        part('line1'),
        part('line2'),
        [part('city'), part('state'), part('postal_code')].whereType<String>().join(' '),
        part('country_code'),
      ].whereType<String>().where((p) => p.isNotEmpty).join(', '),
    );
  }
}

class Order {
  final int id;
  final String number;

  /// pending, processing, shipped, out_for_delivery, delivered, cancelled
  final String status;

  /// unpaid (cash on delivery), pending (card), paid, failed, refunded
  final String paymentStatus;
  final String paymentMethodType;
  final String paymentMethodLabel;
  final String deliveryMethod;
  final Money subtotal;
  final Money discountTotal;
  final Money shippingTotal;
  final Money grandTotal;
  final String? couponCode;
  final ShippingAddress shippingAddress;
  final String? note;
  final int itemCount;
  final List<OrderItem> items;
  final DateTime? placedAt;

  /// When each tracking step happened (null until it has).
  final DateTime? paidAt;
  final DateTime? processingAt;
  final DateTime? shippedAt;
  final DateTime? outForDeliveryAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;

  const Order({
    required this.id,
    required this.number,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethodType,
    required this.paymentMethodLabel,
    required this.deliveryMethod,
    required this.subtotal,
    required this.discountTotal,
    required this.shippingTotal,
    required this.grandTotal,
    this.couponCode,
    required this.shippingAddress,
    this.note,
    required this.itemCount,
    required this.items,
    this.placedAt,
    this.paidAt,
    this.processingAt,
    this.shippedAt,
    this.outForDeliveryAt,
    this.deliveredAt,
    this.cancelledAt,
  });

  bool get isCancelled => status == 'cancelled';
  bool get isDelivered => status == 'delivered';
  bool get isShipped => status == 'shipped';
  bool get isOutForDelivery => status == 'out_for_delivery';

  /// The "To Receive" tab: shipped or out for delivery.
  bool get isToReceive => isShipped || isOutForDelivery;

  /// Card payment still waiting for provider confirmation.
  bool get isAwaitingPayment => paymentStatus == 'pending';

  /// Placed but not shipped yet.
  bool get isToShip => (status == 'pending' || status == 'processing') && !isAwaitingPayment;

  String get statusLabel => switch (status) {
    'pending' => isAwaitingPayment ? 'Awaiting payment' : 'Order placed',
    'processing' => 'Preparing to ship',
    'shipped' => 'On the way',
    'out_for_delivery' => 'Out for delivery',
    'delivered' => 'Delivered',
    'cancelled' => 'Cancelled',
    _ => status,
  };

  String get paymentStatusLabel => switch (paymentStatus) {
    'unpaid' => 'Pay on delivery',
    'pending' => 'Payment pending',
    'paid' => 'Paid',
    'failed' => 'Payment failed',
    'refunded' => 'Refunded',
    _ => paymentStatus,
  };

  /// Rough delivery estimate from the chosen delivery method.
  String get estimatedDelivery {
    final from = placedAt ?? DateTime.now();
    final days = deliveryMethod == 'express' ? 2 : 4;
    final date = from.add(Duration(days: days));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final payment = asMap(json['payment_method']);
    final items = asList(json['items'], OrderItem.fromJson);
    return Order(
      id: asInt(json['id']),
      number: asString(json['number']),
      status: asString(json['status'], 'pending'),
      paymentStatus: asString(json['payment_status'], 'unpaid'),
      paymentMethodType: asString(payment['type']),
      paymentMethodLabel: asString(payment['label']),
      deliveryMethod: asString(json['delivery_method'], 'standard'),
      subtotal: Money.parse(json['subtotal']),
      discountTotal: Money.parse(json['discount_total']),
      shippingTotal: Money.parse(json['shipping_total']),
      grandTotal: Money.parse(json['grand_total']),
      couponCode: asStringOrNull(json['coupon_code']),
      shippingAddress: ShippingAddress.fromJson(asMap(json['shipping_address'])),
      note: asStringOrNull(json['note']),
      itemCount: asInt(json['item_count'], items.fold<int>(0, (sum, i) => sum + i.quantity)),
      items: items,
      placedAt: asDate(json['placed_at']),
      paidAt: asDate(json['paid_at']),
      processingAt: asDate(json['processing_at']),
      shippedAt: asDate(json['shipped_at']),
      outForDeliveryAt: asDate(json['out_for_delivery_at']),
      deliveredAt: asDate(json['delivered_at']),
      cancelledAt: asDate(json['cancelled_at']),
    );
  }
}
