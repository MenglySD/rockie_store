/// A money amount from the API ("25.00"), kept as integer cents so the app
/// never does floating-point price math. Display only; totals come from the server.
class Money implements Comparable<Money> {
  final int cents;

  const Money(this.cents);

  static const zero = Money(0);

  /// Parses "25.00", "25", 25, 25.5 or null (→ 0) without throwing.
  factory Money.parse(Object? value) {
    if (value == null) return zero;
    if (value is int) return Money(value * 100);
    if (value is double) return Money((value * 100).round());

    final text = value.toString().trim();
    final match = RegExp(r'^(-)?(\d*)(?:\.(\d+))?$').firstMatch(text);
    if (match == null) return zero;

    final negative = match.group(1) != null;
    final whole = int.tryParse(match.group(2)!.isEmpty ? '0' : match.group(2)!) ?? 0;
    final fraction = int.tryParse((match.group(3) ?? '0').padRight(2, '0').substring(0, 2)) ?? 0;
    final cents = whole * 100 + fraction;
    return Money(negative ? -cents : cents);
  }

  bool get isZero => cents == 0;

  /// "25.00"
  String get amount {
    final abs = cents.abs();
    return '${cents < 0 ? '-' : ''}${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  }

  /// "$25.00" (the store currency is USD).
  String format({String symbol = '\$'}) {
    final abs = cents.abs();
    return '${cents < 0 ? '-' : ''}$symbol${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  }

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  bool operator >(Money other) => cents > other.cents;
  bool operator <(Money other) => cents < other.cents;

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => format();
}
