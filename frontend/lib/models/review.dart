import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:rockie_store/models/json.dart';

/// A customer review, optionally with photos.
class Review {
  final int id;
  final String name;

  /// The reviewer's photo URL, an emoji (sample reviews), or empty.
  final String avatar;
  final int rating;
  final String text;
  final List<String> images;
  final bool isVerifiedPurchase;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.name,
    required this.avatar,
    required this.rating,
    required this.text,
    required this.images,
    this.isVerifiedPurchase = false,
    this.createdAt,
  });

  bool get avatarIsImage => avatar.startsWith('http://') || avatar.startsWith('https://');

  /// First letter of the name, shown when there is no photo.
  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  /// "2 days ago", like the old hard-coded data.
  String get date {
    final created = createdAt;
    if (created == null) return '';
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return '1 day ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 14) return '1 week ago';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7} weeks ago';
    return '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
  }

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: asInt(json['id']),
    name: asString(json['name'], 'Customer'),
    avatar: asString(json['avatar']),
    rating: asInt(json['rating']),
    text: asString(json['body']),
    images: asStringList(json['images']),
    isVerifiedPurchase: asBool(json['is_verified_purchase']),
    createdAt: asDate(json['created_at']),
  );
}
