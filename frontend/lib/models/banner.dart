import 'package:rockie_store/models/json.dart';

/// A home slider image from GET /banners.
/// (Named PromoBanner because Flutter already has a `Banner` widget.)
class PromoBanner {
  final int id;
  final String? title;
  final String imageUrl;

  /// Tapping the banner opens this product, when set.
  final int? productId;

  const PromoBanner({
    required this.id,
    this.title,
    required this.imageUrl,
    this.productId,
  });

  factory PromoBanner.fromJson(Map<String, dynamic> json) => PromoBanner(
    id: asInt(json['id']),
    title: asStringOrNull(json['title']),
    imageUrl: asString(json['image_url']),
    productId: asIntOrNull(json['product_id']),
  );
}
