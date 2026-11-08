import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/product_image.dart';
import 'package:rockie_store/models/cart.dart';
import 'package:rockie_store/models/coupon.dart';
import 'package:rockie_store/models/money.dart';
import 'package:rockie_store/provider/cart_provider.dart';
import 'package:rockie_store/screen/checkout_screen.dart';
import 'package:rockie_store/screen/coupons_screen.dart';
import 'package:rockie_store/theme/app_colors.dart';

/// Cart contents shared by [CartScreen] (pushed) and [ShopCartScreen] (tab).
///
/// Everything shown here comes from the server cart (GET /cart). The
/// checkboxes are the server's selection: the totals count only the ticked
/// items and checkout orders only those (the rest stay in the cart).
class CartView extends StatefulWidget {
  /// Show the big "Cart" title above the item count (tab layout).
  final bool showTitle;

  const CartView({super.key, this.showTitle = true});

  @override
  State<CartView> createState() => _CartViewState();
}

class _CartViewState extends State<CartView> {
  final TextEditingController _couponController = TextEditingController();

  /// The item whose Delete button is showing (one at a time).
  final ValueNotifier<int?> _openItemId = ValueNotifier(null);

  CartProvider get _cart => context.read<CartProvider>();

  @override
  void initState() {
    super.initState();
    // The cart shows standard shipping; checkout switches to express if chosen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cart.load(deliveryMethod: 'standard');
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
    _openItemId.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    try {
      await action();
      if (mounted && success != null) showMessage(context, success);
    } catch (error) {
      if (mounted) showApiError(context, error, onRetry: () => _run(action, success: success));
    }
  }

  void _toggleSelectAll(Cart cart) => _run(() => _cart.setAllSelected(!cart.allSelected));

  void _toggleItem(CartItem item) => _run(() => _cart.setSelected(item, !item.isSelected));

  void _changeQuantity(CartItem item, int delta) {
    final next = item.quantity + delta;
    if (next < 1) return;
    if (delta > 0 && next > item.maxQuantity) {
      showMessage(
        context,
        item.stock < item.purchaseLimit
            ? 'Only ${item.stock} left in stock.'
            : 'You can buy at most ${item.purchaseLimit} of this item.',
      );
      return;
    }
    _run(() => _cart.updateQuantity(item, next));
  }

  Future<void> _useCoupon() async {
    final coupon = await Navigator.push<Coupon>(
      context,
      MaterialPageRoute(builder: (_) => const CouponsScreen(selectCoupon: true)),
    );
    if (coupon == null || !mounted) return;
    _applyCoupon(coupon.code);
  }

  Future<void> _applyCoupon([String? selectedCode]) async {
    final code = (selectedCode ?? _couponController.text).trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    await _run(() async {
      await _cart.applyCoupon(code);
      _couponController.clear();
    }, success: '${code.toUpperCase()} applied.');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CartProvider>();
    final cart = provider.cart;

    if (!provider.loaded && provider.loading) return const LoadingView();
    if (!provider.loaded && provider.error != null) {
      return ErrorView(error: provider.error!, onRetry: provider.load);
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: mainColor,
          onRefresh: provider.load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderRow(cart),
                const SizedBox(height: 14),
                if (cart.isEmpty)
                  _buildEmptyCart()
                else ...[
                  for (final item in cart.items) ...[
                    _SwipeToDelete(
                      key: ValueKey(item.id),
                      id: item.id,
                      openId: _openItemId,
                      enabled: !provider.busy,
                      onDelete: () => _run(() => _cart.removeItem(item), success: 'Removed from cart'),
                      child: _CartItemCard(
                        item: item,
                        selected: item.isSelected,
                        enabled: !provider.busy,
                        onToggle: () => _toggleItem(item),
                        onIncrement: () => _changeQuantity(item, 1),
                        onDecrement: () => _changeQuantity(item, -1),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  _buildCouponField(cart, provider.busy),
                  const SizedBox(height: 16),
                  _buildSummaryCard(cart),
                  const SizedBox(height: 20),
                  _buildCheckoutButton(cart, provider.busy),
                ],
              ],
            ),
          ),
        ),
        if (provider.busy || (provider.loading && provider.loaded))
          const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(color: mainColor, minHeight: 2)),
      ],
    );
  }

  Widget _buildEmptyCart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 56,
            color: Color(0xFFB9B9B9),
          ),
          SizedBox(height: 14),
          Text(
            'Your cart is empty',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Add something you love and it will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF777777)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(Cart cart) {
    final allSelected = cart.allSelected;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showTitle) ...[
              const Text(
                "Cart",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              allSelected || cart.items.isEmpty
                  ? "${cart.itemCount} items"
                  : "${cart.selectedItemCount} of ${cart.itemCount} items selected",
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            if (cart.items.isNotEmpty) ...[
              const SizedBox(height: 2),
              const Text(
                'Swipe an item left to delete',
                style: TextStyle(fontSize: 11, color: Colors.black38),
              ),
            ],
          ],
        ),
        if (cart.items.isNotEmpty)
          GestureDetector(
            onTap: context.read<CartProvider>().busy ? null : () => _toggleSelectAll(cart),
            child: Text(
              allSelected ? "Deselect All" : "Select All",
              style: const TextStyle(
                color: mainColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCouponField(Cart cart, bool busy) {
    final applied = cart.coupon;
    if (applied != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF5D0B8)),
        ),
        child: Row(
          children: [
            Icon(
              applied.isApplicable ? Icons.check_circle : Icons.info_outline,
              color: applied.isApplicable ? const Color(0xFF2E9E5B) : Colors.orange,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${applied.code} · ${applied.title}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (applied.message != null)
                    Text(applied.message!, style: const TextStyle(fontSize: 11, color: Colors.orange)),
                ],
              ),
            ),
            TextButton(
              onPressed: busy ? null : () => _run(_cart.removeCoupon, success: 'Coupon removed'),
              child: const Text('Remove', style: TextStyle(color: mainColor)),
            ),
          ],
        ),
      );
    }

    final hasText = _couponController.text.trim().isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF5D0B8)),
            ),
            child: TextField(
              controller: _couponController,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _applyCoupon(),
              decoration: const InputDecoration(
                hintText: "Coupon Code",
                hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: busy ? null : (hasText ? () => _applyCoupon() : _useCoupon),
          style: ElevatedButton.styleFrom(
            backgroundColor: mainColor.withValues(alpha: 0.12),
            foregroundColor: mainColor,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: Text(
            hasText ? "Apply" : "Use",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(Cart cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEEF3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _SummaryRow(label: "Subtotal", value: cart.subtotal),
          const SizedBox(height: 10),
          _SummaryRow(label: "Shipping", value: cart.shippingTotal),
          const SizedBox(height: 10),
          _SummaryRow(label: "Discount", value: cart.discountTotal, isDiscount: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF3B08A)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                cart.grandTotal.format(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: mainColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(Cart cart, bool busy) {
    return Column(
      children: [
        if (!cart.hasSelection)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Select the items you want to buy.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          )
        else if (cart.hasIssues)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Some selected items need your attention before checkout.',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: busy || !cart.hasSelection || cart.hasIssues
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CheckoutScreen()),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: mainColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Checkout (${cart.grandTotal.format()})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final Money value;
  final bool isDiscount;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    final display = isDiscount && !value.isZero ? '-${value.format()}' : value.format();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        Text(
          display,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDiscount ? const Color(0xFF2E9E5B) : Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Drag the card left to reveal a red Delete button behind it.
/// Releasing past half the button keeps it open; a tap on the card, a drag
/// back to the right, or opening another card closes it.
class _SwipeToDelete extends StatefulWidget {
  final int id;
  final ValueNotifier<int?> openId;
  final bool enabled;
  final VoidCallback onDelete;
  final Widget child;

  const _SwipeToDelete({
    super.key,
    required this.id,
    required this.openId,
    required this.enabled,
    required this.onDelete,
    required this.child,
  });

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete> with SingleTickerProviderStateMixin {
  static const double _actionWidth = 88;

  /// 0 = closed, 1 = Delete button fully showing.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  bool get _isOpen => _controller.value > 0;
  bool _wasOpen = false;

  @override
  void initState() {
    super.initState();
    widget.openId.addListener(_onOtherOpened);
    // Rebuild only when the card switches between closed and (partly) open.
    _controller.addListener(() {
      if (_isOpen != _wasOpen && mounted) setState(() => _wasOpen = _isOpen);
    });
  }

  @override
  void dispose() {
    widget.openId.removeListener(_onOtherOpened);
    _controller.dispose();
    super.dispose();
  }

  void _onOtherOpened() {
    if (widget.openId.value != widget.id && _isOpen) _controller.animateTo(0, curve: Curves.easeOut);
  }

  void _open() {
    widget.openId.value = widget.id;
    _controller.animateTo(1, curve: Curves.easeOut);
  }

  void _close() {
    if (widget.openId.value == widget.id) widget.openId.value = null;
    _controller.animateTo(0, curve: Curves.easeOut);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _controller.value -= (details.primaryDelta ?? 0) / _actionWidth;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300 || (velocity <= 300 && _controller.value > 0.5)) {
      _open();
    } else {
      _close();
    }
  }

  void _delete() {
    _close();
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: widget.enabled ? _onDragUpdate : null,
          onHorizontalDragEnd: widget.enabled ? _onDragEnd : null,
          // While open, a tap anywhere on the card just closes it.
          onTap: _isOpen ? _close : null,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(-_actionWidth * _controller.value, 0),
              child: child,
            ),
            child: AbsorbPointer(
              absorbing: _isOpen,
              child: widget.child,
            ),
          ),
        ),
        // Delete button in the space the card slides away from. It sits on
        // top of the card's gesture area so its tap is not swallowed, and
        // only takes taps while it is showing.
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: _actionWidth - 8,
          child: IgnorePointer(
            ignoring: !_isOpen,
            child: FadeTransition(
              opacity: _controller,
              child: Material(
                color: Colors.red,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: widget.enabled ? _delete : null,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white, size: 24),
                      SizedBox(height: 4),
                      Text('Delete', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final bool selected;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartItemCard({
    required this.item,
    required this.selected,
    required this.enabled,
    required this.onToggle,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final issue = item.issueMessage;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: issue == null ? null : Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 26, right: 10),
              decoration: BoxDecoration(
                color: selected ? mainColor : const Color(0xFFE6E6E6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: productImage(item.imageUrl, width: 70, height: 70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Variant: ${item.variant}",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (issue != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(issue, style: const TextStyle(fontSize: 11, color: Colors.red)),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.unitPrice.format(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: mainColor,
                      ),
                    ),
                    _QuantityStepper(
                      quantity: item.quantity,
                      onIncrement: enabled ? onIncrement : null,
                      onDecrement: enabled && item.quantity > 1 ? onDecrement : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(icon: Icons.remove, onTap: onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$quantity', style: const TextStyle(fontSize: 13)),
          ),
          _StepperButton(icon: Icons.add, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 14, color: onTap == null ? Colors.black26 : Colors.black54),
      ),
    );
  }
}
