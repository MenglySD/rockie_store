import 'package:dio/dio.dart';
import 'package:rockie_store/models/banner.dart';
import 'package:rockie_store/models/category.dart';
import 'package:rockie_store/models/json.dart';
import 'package:rockie_store/models/paginated.dart';
import 'package:rockie_store/models/product.dart';
import 'package:rockie_store/models/review.dart';
import 'package:rockie_store/services/api_client.dart';

enum ProductSort {
  newest('newest'),
  priceAsc('price_asc'),
  priceDesc('price_desc'),
  popular('popular'),
  rating('rating');

  final String value;
  const ProductSort(this.value);
}

class ProductQuery {
  final int? categoryId;

  /// Products in any of these categories, e.g. every "Women's" category.
  final List<int> categoryIds;
  final String? q;
  final ProductSort sort;
  final String? minPrice;
  final String? maxPrice;

  const ProductQuery({
    this.categoryId,
    this.categoryIds = const [],
    this.q,
    this.sort = ProductSort.newest,
    this.minPrice,
    this.maxPrice,
  });
}

class ProductRepository {
  final ApiClient _api;
  ProductRepository(this._api);

  List<Category>? _categoriesCache;

  /// Home slider images, in display order.
  Future<List<PromoBanner>> banners() async {
    final body = await _api.get('/banners');
    return asList(asMap(body)['data'], PromoBanner.fromJson);
  }

  Future<List<Category>> categories({bool refresh = false}) async {
    if (!refresh && _categoriesCache != null) return _categoriesCache!;
    final body = await _api.get('/categories');
    return _categoriesCache = asList(asMap(body)['data'], Category.fromJson);
  }

  Future<Paginated<Product>> products(ProductQuery query, {int page = 1, int perPage = 20}) async {
    final body = await _api.get('/products', query: {
      'category_id': query.categoryId,
      'category_ids': query.categoryIds.isEmpty ? null : query.categoryIds.join(','),
      'q': query.q?.trim(),
      'sort': query.sort.value,
      'min_price': query.minPrice,
      'max_price': query.maxPrice,
      'page': page,
      'per_page': perPage,
    });
    return Paginated.fromJson(asMap(body), Product.fromJson);
  }

  Future<Product> product(int id) async {
    final body = await _api.get('/products/$id');
    return Product.fromJson(asMap(asMap(body)['data']));
  }

  Future<Paginated<Review>> reviews(int productId, {int page = 1, int perPage = 10}) async {
    final body = await _api.get('/products/$productId/reviews', query: {
      'page': page,
      'per_page': perPage,
    });
    return Paginated.fromJson(asMap(body), Review.fromJson);
  }

  /// Only allowed after the user has ordered the product (403 otherwise).
  /// Up to 5 photos (JPG, PNG or WebP, 5 MB each) are uploaded with it.
  Future<Review> submitReview(
    int productId, {
    required int rating,
    required String body,
    List<ReviewPhoto> photos = const [],
  }) async {
    final form = FormData()
      ..fields.addAll([MapEntry('rating', '$rating'), MapEntry('body', body)])
      ..files.addAll([
        for (final photo in photos)
          MapEntry('images[]', MultipartFile.fromBytes(photo.bytes, filename: photo.filename)),
      ]);
    final response = await _api.post('/products/$productId/reviews', data: form);
    return Review.fromJson(asMap(asMap(response)['data']));
  }
}

/// A photo picked for a review.
class ReviewPhoto {
  final List<int> bytes;
  final String filename;

  const ReviewPhoto(this.bytes, this.filename);
}
