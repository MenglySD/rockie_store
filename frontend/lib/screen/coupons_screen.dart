import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/models/coupon.dart';
import 'package:rockie_store/provider/cart_provider.dart';
import 'package:rockie_store/repositories/cart_repository.dart';
import 'package:rockie_store/theme/app_colors.dart';

/// Available coupons from GET /coupons.
/// With [selectCoupon] the chosen coupon is returned to the cart;
/// otherwise "Use" applies it to the cart directly.
class CouponsScreen extends StatefulWidget {
  final bool selectCoupon;

  const CouponsScreen({super.key, this.selectCoupon = false});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  List<Coupon> _coupons = const [];
  bool _loading = true;
  Object? _error;
  String? _applyingCode;

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
      final coupons = await context.read<CartRepository>().coupons();
      if (mounted) setState(() => _coupons = coupons);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _use(Coupon coupon) async {
    if (widget.selectCoupon) {
      Navigator.pop(context, coupon);
      return;
    }
    setState(() => _applyingCode = coupon.code);
    try {
      // The server checks eligibility (minimum spend, expiry).
      await context.read<CartProvider>().applyCoupon(coupon.code);
      if (mounted) showMessage(context, '${coupon.code} applied to your cart');
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _applyingCode = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appliedCode = context.watch<CartProvider>().cart.coupon?.code;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.selectCoupon ? 'Choose a Coupon' : 'My Coupons',
          style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading && _coupons.isEmpty
          ? const LoadingView()
          : _error != null && _coupons.isEmpty
          ? ErrorView(error: _error!, onRetry: _load)
          : RefreshIndicator(
              color: mainColor,
              onRefresh: _load,
              child: _coupons.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 160),
                        Center(child: Text('No coupons available', style: TextStyle(color: Colors.black54))),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _coupons.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final coupon = _coupons[index];
                        return _CouponCard(
                          coupon: coupon,
                          applied: coupon.code == appliedCode,
                          busy: _applyingCode == coupon.code,
                          onUse: _applyingCode == null ? () => _use(coupon) : null,
                        );
                      },
                    ),
            ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final Coupon coupon;
  final bool applied;
  final bool busy;
  final VoidCallback? onUse;

  const _CouponCard({required this.coupon, required this.applied, required this.busy, required this.onUse});

  @override
  Widget build(BuildContext context) {
    final color = applied ? const Color(0xFF999999) : mainColor;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E9E6)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: color.withValues(alpha: .10), shape: BoxShape.circle),
                  child: Icon(coupon.icon, color: color, size: 27),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(coupon.title, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20)),
                      const SizedBox(height: 3),
                      Text(coupon.subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF5F5A58))),
                    ],
                  ),
                ),
                if (applied)
                  const Text('APPLIED', style: TextStyle(color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.w700))
                else
                  SizedBox(
                    height: 34,
                    child: OutlinedButton(
                      onPressed: onUse,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: mainColor,
                        side: const BorderSide(color: mainColor),
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      child: busy ? const ButtonSpinner(color: mainColor) : const Text('Use'),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EDEA)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(coupon.condition, style: const TextStyle(fontSize: 11, color: Color(0xFF625C59))),
                      const SizedBox(height: 4),
                      Text(coupon.expiry, style: const TextStyle(fontSize: 10, color: Color(0xFF99918E))),
                    ],
                  ),
                ),
                Text(coupon.code, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
