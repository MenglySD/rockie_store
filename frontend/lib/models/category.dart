import 'package:rockie_store/models/json.dart';

class Category {
  final int id;
  final String name;
  final String slug;
  final String? imageUrl;
  final int productsCount;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.productsCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: asInt(json['id']),
    name: asString(json['name']),
    slug: asString(json['slug']),
    imageUrl: asStringOrNull(json['image_url']),
    productsCount: asInt(json['products_count']),
  );
}
