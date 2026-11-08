import 'package:flutter/material.dart';
import 'package:rockie_store/helpers/cart_view.dart';
import 'package:rockie_store/screen/notification_screen.dart';

/// Cart tab in the bottom navigation (logo + bell header).
class ShopCartScreen extends StatelessWidget {
  const ShopCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            const Expanded(child: CartView()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 105, height: 30),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: Colors.black,
              size: 24,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
