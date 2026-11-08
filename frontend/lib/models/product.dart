import 'package:rockie_store/models/category.dart';
import 'package:rockie_store/models/json.dart';
import 'package:rockie_store/models/money.dart';
import 'package:rockie_store/models/review.dart';

class ProductVariant {
  final int id;
  final String sku;
  final String? color;
  final String? size;
  final int stock;
  final int purchaseLimit;

  const ProductVariant({
    required this.id,
    required this.sku,
    this.color,
    this.size,
    required this.stock,
    required this.purchaseLimit,
  });

  bool get inStock => stock > 0;

  /// The most the user may put in the cart for this variant.
  int get maxQuantity => stock < purchaseLimit ? stock : purchaseLimit;

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
    id: asInt(json['id']),
    sku: asString(json['sku']),
    color: asStringOrNull(json['color']),
    size: asStringOrNull(json['size']),
    stock: asInt(json['stock']),
    purchaseLimit: asInt(json['purchase_limit'], 10),
  );
}

/// A product from `GET /products` (list card) or `GET /products/{id}` (detail).
/// Detail-only fields are empty on list items.
class Product {
  final int id;
  final int? categoryId;
  final Category? category;
  final String title;
  final String? description;
  final Money price;
  final Money originalPrice;
  final int discountPct;
  final int soldCount;
  final double rating;
  final int reviewCount;
  final List<String> images;
  final List<String> colors;
  final List<String> sizes;
  final List<ProductVariant> variants;
  final List<Review> reviews;
  final int purchaseLimit;
  final bool inStock;

  const Product({
    required this.id,
    this.categoryId,
    this.category,
    required this.title,
    this.description,
    required this.price,
    required this.originalPrice,
    this.discountPct = 0,
    this.soldCount = 0,
    this.rating = 0,
    this.reviewCount = 0,
    this.images = const [],
    this.colors = const [],
    this.sizes = const [],
    this.variants = const [],
    this.reviews = const [],
    this.purchaseLimit = 10,
    this.inStock = true,
  });

  String? get imageUrl => images.isEmpty ? null : images.first;

  bool get hasDiscount => originalPrice > price;

  /// "70+" / "1.2k+", from the integer `sold_count`.
  String get sold => formatSoldCount(soldCount);

  /// The variant matching a color/size selection, if any.
  ProductVariant? variantFor({String? color, String? size}) {
    for (final variant in variants) {
      if (variant.color == color && variant.size == size) return variant;
    }
    return null;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final images = json['images'] is List
        ? asStringList(json['images'])
        : [if (json['image_url'] != null) json['image_url'].toString()];
    final summary = asMap(json['review_summary']);
    final categoryJson = json['category'];

    return Product(
      id: asInt(json['id']),
      categoryId: asIntOrNull(json['category_id']) ??
          (categoryJson is Map ? asIntOrNull(categoryJson['id']) : null),
      category: categoryJson is Map
          ? Category.fromJson(Map<String, dynamic>.from(categoryJson))
          : null,
      title: asString(json['title']).trim(),
      description: asStringOrNull(json['description']),
      price: Money.parse(json['price']),
      originalPrice: Money.parse(json['original_price'] ?? json['price']),
      discountPct: asInt(json['discount_percent']),
      soldCount: asInt(json['sold_count']),
      rating: asDouble(json['rating']),
      reviewCount: asInt(json['review_count']),
      images: images,
      colors: asStringList(json['colors']),
      sizes: asStringList(json['sizes']),
      variants: asList(json['variants'], ProductVariant.fromJson),
      reviews: asList(summary['latest'], Review.fromJson),
      purchaseLimit: asInt(json['purchase_limit'], 10),
      inStock: asBool(json['in_stock'], true),
    );
  }
}

String formatSoldCount(int count) {
  if (count >= 1000) {
    final thousands = (count / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    return '${thousands}k+';
  }
  return count > 0 ? '$count+' : '0';
}
