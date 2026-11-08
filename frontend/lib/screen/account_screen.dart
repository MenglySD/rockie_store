import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/product_image.dart';
import 'package:rockie_store/helpers/session.dart';
import 'package:rockie_store/models/order.dart';
import 'package:rockie_store/provider/auth_provider.dart';
import 'package:rockie_store/repositories/order_repository.dart';
import 'package:rockie_store/screen/notification_screen.dart';
import 'package:rockie_store/screen/order_history_screen.dart';
import 'package:rockie_store/screen/address_screen.dart';
import 'package:rockie_store/screen/coupons_screen.dart';
import 'package:rockie_store/screen/payment_methods_screen.dart';
import 'package:rockie_store/screen/order_status_screen.dart';
import 'package:rockie_store/screen/setting_screen.dart';
import 'package:rockie_store/screen/edit_profile_screen.dart';
import 'package:rockie_store/theme/app_colors.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  List<Order> _orders = const [];
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  /// Profile from GET /me and order badges from GET /orders.
  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    final orders = context.read<OrderRepository>();
    try {
      final userRefresh = auth.refreshUser();
      final page = await orders.list(perPage: 50);
      await userRefresh;
      if (mounted) setState(() => _orders = page.items);
    } catch (error) {
      if (mounted) showApiError(context, error, onRetry: _refresh);
    }
  }

  int get _toPayCount => _orders.where((o) => o.isAwaitingPayment).length;
  int get _toShipCount => _orders.where((o) => o.isToShip).length;
  int get _toReceiveCount => _orders.where((o) => o.isToReceive).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: RefreshIndicator(
                color: mainColor,
                onRefresh: _refresh,
                child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserRow(context),
                    const SizedBox(height: 16),
                    _buildOrdersCard(context),
                    const SizedBox(height: 16),
                    _buildMenuCard(context),
                    const SizedBox(height: 32),
                    _buildLogoutButton(context),
                  ],
                ),
              ),
              ),
            ),
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
          icon: const Icon(Icons.notifications_none, color: Colors.black, size: 24),
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

  Widget _buildUserRow(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final avatar = networkImageProvider(user?.avatarUrl);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: user == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.white,
          backgroundImage: avatar ?? const AssetImage('assets/images/profile.png'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            if (user?.email != null)
              Text(
                user!.email!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: mainColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "MEMBER SHIP",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        ),
        const Icon(Icons.chevron_right, color: Colors.black38),
      ],
      ),
      ),
    );
  }

  Widget _buildOrdersCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "My Orders",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              InkWell(
                onTap: () => _openOrderHistory(context),
                child: Row(
                children: const [
                  Text(
                    "View All",
                    style: TextStyle(
                      color: mainColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: mainColor, size: 16),
                ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _OrderIcon(
                icon: Icons.payments_outlined,
                label: "To Pay",
                badgeCount: _toPayCount > 0 ? _toPayCount : null,
                onTap: () => _openOrderStatus(context, OrderStatus.toPay),
              ),
              _OrderIcon(
                icon: Icons.local_shipping_outlined,
                label: "To Ship",
                badgeCount: _toShipCount > 0 ? _toShipCount : null,
                onTap: () => _openOrderStatus(context, OrderStatus.toShip),
              ),
              _OrderIcon(
                icon: Icons.inventory_2_outlined,
                label: "To Receive",
                badgeCount: _toReceiveCount > 0 ? _toReceiveCount : null,
                onTap: () => _openOrderStatus(context, OrderStatus.toReceive),
              ),
              _OrderIcon(
                icon: Icons.history,
                label: "History",
                onTap: () => _openOrderHistory(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openOrderHistory(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
    );
    if (mounted) _refresh();
  }

  Future<void> _openOrderStatus(BuildContext context, OrderStatus status) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderStatusScreen(status: status)),
    );
    if (mounted) _refresh();
  }

  Widget _buildMenuCard(BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        _MenuRow(
          icon: Icons.confirmation_number_outlined,
          label: "Coupons",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CouponsScreen()),
            );
          },
        ),
        const _MenuDivider(),
        _MenuRow(
          icon: Icons.location_on_outlined,
          label: "Addresses",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddressScreen()),
            );
          },
        ),
        const _MenuDivider(),
        _MenuRow(
          icon: Icons.credit_card_outlined,
          label: "Payment Methods",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()),
            );
          },
        ),
        const _MenuDivider(),
        _MenuRow(
          icon: Icons.settings_outlined,
          label: "Settings",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ],
    ),
  );
}

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loggingOut ? null : () => _logout(context),
        icon: _loggingOut
            ? const ButtonSpinner()
            : const Icon(Icons.logout, size: 18, color: Colors.white),
        label: const Text(
          "Logout",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: mainColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    setState(() => _loggingOut = true);
    await logout(context);
  }
}

class _OrderIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? badgeCount;
  final VoidCallback? onTap;

  const _OrderIcon({required this.icon, required this.label, this.badgeCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F2F0),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: mainColor, size: 20),
            ),
            if (badgeCount != null)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: mainColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$badgeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11.5)),
      ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            const Icon(Icons.chevron_right, size: 18, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 14,
      endIndent: 14,
      color: Color(0xFFF0F0F0),
    );
  }
}
