import 'package:rockie_store/models/json.dart';

/// An in-app notification from `GET /notifications`.
class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String description;
  final Map<String, dynamic> data;
  final bool isUnread;
  final DateTime? createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.data = const {},
    this.isUnread = false,
    this.createdAt,
  });

  int? get orderId => asIntOrNull(data['order_id']);

  /// "2 min ago", "Yesterday", ...
  String get time {
    final created = createdAt;
    if (created == null) return '';
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  NotificationItem markedRead() => NotificationItem(
    id: id,
    type: type,
    title: title,
    description: description,
    data: data,
    isUnread: false,
    createdAt: createdAt,
  );

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    id: asInt(json['id']),
    type: asString(json['type']),
    title: asString(json['title']),
    description: asString(json['body']),
    data: asMap(json['data']),
    isUnread: !asBool(json['is_read']),
    createdAt: asDate(json['created_at']),
  );
}
