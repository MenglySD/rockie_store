import 'package:flutter/material.dart';
import 'package:rockie_store/models/json.dart';
import 'package:rockie_store/models/money.dart';

/// A coupon from `GET /coupons`. Discounts are calculated by the server;
/// this model is for display only.
class Coupon {
  final int id;
  final String code;
  final String title;
  final String subtitle;

  /// percent, fixed or free_shipping
  final String type;
  final Money minimumSpend;
  final DateTime? expiresAt;

  const Coupon({
    required this.id,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.minimumSpend,
    this.expiresAt,
  });

  String get condition =>
      minimumSpend.isZero ? 'No minimum spend' : 'Min. spend ${minimumSpend.format()}';

  String get expiry {
    final date = expiresAt;
    if (date == null) return 'No expiry date';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'Valid until ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String get kind => switch (type) {
    'free_shipping' => 'Shipping',
    'fixed' => 'Limited offer',
    _ => 'Shopping',
  };

  IconData get icon => switch (type) {
    'free_shipping' => Icons.local_shipping_outlined,
    'fixed' => Icons.local_offer_outlined,
    _ => Icons.shopping_bag_outlined,
  };

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
    id: asInt(json['id']),
    code: asString(json['code']),
    title: asString(json['title']),
    subtitle: asString(json['description']),
    type: asString(json['type'], 'percent'),
    minimumSpend: Money.parse(json['min_subtotal']),
    expiresAt: asDate(json['expires_at']),
  );
}
