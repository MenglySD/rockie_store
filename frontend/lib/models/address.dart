import 'package:rockie_store/models/json.dart';

class Address {
  final int id;
  final String? label;
  final String recipientName;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String? state;
  final String? postalCode;
  final String countryCode;
  final bool isDefault;

  const Address({
    required this.id,
    this.label,
    required this.recipientName,
    required this.phone,
    required this.line1,
    this.line2,
    required this.city,
    this.state,
    this.postalCode,
    required this.countryCode,
    this.isDefault = false,
  });

  /// "No. 86A, Street 110, Phnom Penh"
  String get details => [
    line1,
    if (line2 != null && line2!.isNotEmpty) line2,
    [city, if (state != null && state!.isNotEmpty) state, if (postalCode != null && postalCode!.isNotEmpty) postalCode].join(' '),
  ].join(', ');

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    id: asInt(json['id']),
    label: asStringOrNull(json['label']),
    recipientName: asString(json['recipient_name']),
    phone: asString(json['phone']),
    line1: asString(json['line1']),
    line2: asStringOrNull(json['line2']),
    city: asString(json['city']),
    state: asStringOrNull(json['state']),
    postalCode: asStringOrNull(json['postal_code']),
    countryCode: asString(json['country_code']),
    isDefault: asBool(json['is_default']),
  );
}

/// Body for POST/PATCH /addresses: label, full name, phone, street and city.
/// The server fills in the country for new addresses.
class AddressInput {
  final String? label;
  final String recipientName;
  final String phone;
  final String line1;
  final String city;
  final bool isDefault;

  const AddressInput({
    this.label,
    required this.recipientName,
    required this.phone,
    required this.line1,
    required this.city,
    required this.isDefault,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'recipient_name': recipientName,
    'phone': phone,
    'line1': line1,
    'city': city,
    'is_default': isDefault,
  };
}
