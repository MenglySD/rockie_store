import 'package:rockie_store/models/json.dart';

/// Laravel's paginated `{data, links, meta}` response.
class Paginated<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const Paginated({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final meta = asMap(json['meta']);
    final items = asList(json['data'], parse);
    return Paginated(
      items: items,
      currentPage: asInt(meta['current_page'], 1),
      lastPage: asInt(meta['last_page'], 1),
      total: asInt(meta['total'], items.length),
    );
  }
}
