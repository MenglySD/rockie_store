import 'package:rockie_store/models/json.dart';

enum PaymentMethodType {
  cashOnDelivery('cash_on_delivery', 'Cash on delivery'),
  card('card', 'Credit / Debit card');

  final String value;
  final String label;
  const PaymentMethodType(this.value, this.label);

  static PaymentMethodType fromValue(Object? value) =>
      value == card.value ? card : cashOnDelivery;
}

/// A saved payment method. Only brand, last 4 digits and expiry are stored;
/// the full card number and CVV never leave the device.
/// (New methods are always cards; older cash-on-delivery rows still load.)
class PaymentMethod {
  final int id;
  final PaymentMethodType type;
  final String label;
  final String? brand;
  final String? last4;
  final int? expMonth;
  final int? expYear;
  final bool isExpired;
  final bool isDefault;

  const PaymentMethod({
    required this.id,
    required this.type,
    required this.label,
    this.brand,
    this.last4,
    this.expMonth,
    this.expYear,
    this.isExpired = false,
    this.isDefault = false,
  });

  bool get isCard => type == PaymentMethodType.card;

  /// "12/27", or null when unknown.
  String? get expiry => expMonth == null || expYear == null
      ? null
      : '${expMonth.toString().padLeft(2, '0')}/${(expYear! % 100).toString().padLeft(2, '0')}';

  /// "Visa  •••• 4242  ·  Expires 12/27" or "Pay when your order arrives".
  String get subtitle {
    if (!isCard) return 'Pay when your order arrives';
    final card = '${cardBrandName(brand)}  •••• ${last4 ?? '----'}';
    final date = expiry;
    if (date == null) return card;
    return '$card  ·  ${isExpired ? 'Expired' : 'Expires'} $date';
  }

  /// Asset logo for known brands, null otherwise.
  String? get logoAsset => brand?.toLowerCase() == 'visa' ? 'assets/images/logovisa.png' : null;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
    id: asInt(json['id']),
    type: PaymentMethodType.fromValue(json['type']),
    label: asString(json['label']),
    brand: asStringOrNull(json['brand']),
    last4: asStringOrNull(json['last4']),
    expMonth: asIntOrNull(json['exp_month']),
    expYear: asIntOrNull(json['exp_year']),
    isExpired: asBool(json['is_expired']),
    isDefault: asBool(json['is_default']),
  );
}

/// Brand from the first digits of a card number (test numbers work too).
String? detectCardBrand(String digits) {
  if (digits.startsWith('4')) return 'visa';
  if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(digits)) return 'mastercard';
  if (RegExp(r'^3[47]').hasMatch(digits)) return 'amex';
  if (digits.startsWith('62')) return 'unionpay';
  if (RegExp(r'^35').hasMatch(digits)) return 'jcb';
  return null;
}

String cardBrandName(String? brand) => switch (brand?.toLowerCase()) {
  'visa' => 'Visa',
  'mastercard' => 'Mastercard',
  'amex' => 'American Express',
  'unionpay' => 'UnionPay',
  'jcb' => 'JCB',
  _ => 'Card',
};

/// Body for POST /payment-methods. Built from the card form: the full card
/// number and security code are checked on the device and never sent.
class PaymentMethodInput {
  final String? brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final bool isDefault;

  const PaymentMethodInput({
    this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.isDefault,
  });

  Map<String, dynamic> toJson() => {
    'type': PaymentMethodType.card.value,
    'brand': brand,
    'last4': last4,
    'exp_month': expMonth,
    'exp_year': expYear,
    'is_default': isDefault,
  };
}
