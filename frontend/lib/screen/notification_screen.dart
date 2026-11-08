import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/models/notification.dart';
import 'package:rockie_store/repositories/order_repository.dart';
import 'package:rockie_store/screen/purchase_order_detail_screen.dart';
import 'package:rockie_store/theme/app_colors.dart';

/// In-app notifications from GET /notifications.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationItem> notifications = const [];
  bool _loading = true;
  bool _markingAll = false;
  Object? _error;

  OrderRepository get _repository => context.read<OrderRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repository.notifications();
      if (mounted) setState(() => notifications = page.items);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll || !notifications.any((n) => n.isUnread)) return;
    setState(() => _markingAll = true);
    try {
      await _repository.markAllNotificationsRead();
      if (mounted) setState(() => notifications = notifications.map((n) => n.markedRead()).toList());
    } catch (error) {
      if (mounted) showApiError(context, error, onRetry: _markAllRead);
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _open(int index) async {
    final item = notifications[index];
    if (item.isUnread) {
      setState(() {
        notifications = [...notifications]..[index] = item.markedRead();
      });
      // Best effort; the list refreshes from the server next time anyway.
      _repository.markNotificationRead(item.id).catchError((_) {});
    }
    final orderId = item.orderId;
    if (orderId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PurchaseOrderDetailScreen(orderId: orderId)),
      );
    }
  }

  Widget _iconFor(NotificationItem item) {
    final (Color background, Widget icon) = switch (item.type) {
      'order_placed' => (const Color(0xFFFFF2EE), const Center(child: Text('🛍️', style: TextStyle(fontSize: 24)))),
      'order_paid' => (const Color(0xFFEFFBF1), const Center(child: Text('💳', style: TextStyle(fontSize: 24)))),
      'order_shipped' => (const Color(0xFFEBF3FE), const Center(child: Text('🚚', style: TextStyle(fontSize: 24)))),
      'order_out_for_delivery' => (const Color(0xFFFFF2EE), const Center(child: Text('🛵', style: TextStyle(fontSize: 24)))),
      'order_cancelled' => (const Color(0xFFF2F2F2), const Icon(Icons.close, color: Color(0xFF777777), size: 24)),
      'order_delivered' => (const Color(0xFFEFFBF1), const Icon(Icons.check, color: Color(0xFF388E3C), size: 24)),
      _ => (const Color(0xFFFFF0F5), const Center(child: Text('🎉', style: TextStyle(fontSize: 24)))),
    };
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFEAEAEA),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
              onPressed: () {
                Navigator.pop(context); // Navigates back to the previous screen
              },
            ),
          ),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _markingAll ? null : _markAllRead,
            child: const Text(
              'Mark All Read',
              style: TextStyle(
                color: Color(0xFFFF6C37),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading && notifications.isEmpty
          ? const LoadingView()
          : _error != null && notifications.isEmpty
          ? ErrorView(error: _error!, onRetry: _load)
          : RefreshIndicator(
              color: mainColor,
              onRefresh: _load,
              child: notifications.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        EmptyView(icon: Icons.notifications_none, title: 'No notifications yet'),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: notifications.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _open(index),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                            ),
                            child: Stack(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _iconFor(item),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(right: 16.0),
                                            child: Text(
                                              item.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.description,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            item.time,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.isUnread)
                                  const Positioned(
                                    top: 2,
                                    right: 0,
                                    child: CircleAvatar(
                                      radius: 5,
                                      backgroundColor: Color(0xFFFF522B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
