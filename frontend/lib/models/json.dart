// Small, forgiving JSON readers so a missing or oddly typed field never crashes a screen.

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool asBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return fallback;
}

String asString(Object? value, [String fallback = '']) => value?.toString() ?? fallback;

String? asStringOrNull(Object? value) => value?.toString();

DateTime? asDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

Map<String, dynamic> asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<T> asList<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((e) => parse(Map<String, dynamic>.from(e))).toList();
}

List<String> asStringList(Object? value) =>
    value is List ? value.map((e) => e.toString()).toList() : const [];
