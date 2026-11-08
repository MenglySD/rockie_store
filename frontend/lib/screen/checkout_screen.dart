import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/models/address.dart';
import 'package:rockie_store/models/payment_method.dart';
import 'package:rockie_store/provider/cart_provider.dart';
import 'package:rockie_store/repositories/address_repository.dart';
import 'package:rockie_store/repositories/order_repository.dart';
import 'package:rockie_store/repositories/payment_method_repository.dart';
import 'package:rockie_store/screen/address_screen.dart';
import 'package:rockie_store/screen/order_confirmation_screen.dart';
import 'package:rockie_store/screen/payment_methods_screen.dart';
import 'package:rockie_store/services/api_exception.dart';
import 'package:uuid/uuid.dart';

/// Places an order from the server cart. The user must pick an address and a
/// payment method; only the ones they marked as default are preselected.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedDelivery = 'standard'; // 'standard' or 'express'

  List<Address> _addresses = const [];
  List<PaymentMethod> _paymentMethods = const [];
  int? _selectedAddressId;
  int? _selectedPaymentId;

  bool _loading = true;
  Object? _error;
  bool _placing = false;

  /// One key per checkout: retries after a timeout can never create a second order.
  final String _idempotencyKey = const Uuid().v4();

  static const Color _primaryOrange = Color(0xFFFF4D00);
  static const Color _backgroundColor = Color(0xFFF8F9FA);

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
    final cart = context.read<CartProvider>();
    try {
      final results = await Future.wait([
        context.read<AddressRepository>().list(),
        context.read<PaymentMethodRepository>().list(),
        cart.load(deliveryMethod: _selectedDelivery),
      ]);
      if (!mounted) return;
      setState(() {
        _setAddresses(results[0] as List<Address>);
        _setPaymentMethods(results[1] as List<PaymentMethod>);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Keep the current choice; otherwise preselect only an explicit default.
  void _setAddresses(List<Address> addresses) {
    _addresses = addresses;
    if (!addresses.any((a) => a.id == _selectedAddressId)) {
      _selectedAddressId = addresses.where((a) => a.isDefault).firstOrNull?.id;
    }
  }

  void _setPaymentMethods(List<PaymentMethod> methods) {
    _paymentMethods = methods;
    if (!methods.any((m) => m.id == _selectedPaymentId)) {
      _selectedPaymentId = methods.where((m) => m.isDefault).firstOrNull?.id;
    }
  }

  Future<void> _selectDelivery(String id) async {
    if (id == _selectedDelivery) return;
    setState(() => _selectedDelivery = id);
    // Shipping and totals are recalculated by the server.
    await context.read<CartProvider>().load(deliveryMethod: id);
  }

  Future<void> _addAddress() async {
    final saved = await showAddressForm(context);
    if (saved == null || !mounted) return;
    final addresses = await context.read<AddressRepository>().list();
    if (!mounted) return;
    setState(() {
      _setAddresses(addresses);
      _selectedAddressId = saved.id; // the user just created it for this order
    });
  }

  Future<void> _addPaymentMethod() async {
    final saved = await showPaymentMethodForm(context);
    if (saved == null || !mounted) return;
    final methods = await context.read<PaymentMethodRepository>().list();
    if (!mounted) return;
    setState(() {
      _setPaymentMethods(methods);
      _selectedPaymentId = saved.id;
    });
  }

  Future<void> _chooseAddress() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('Choose address', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            for (final address in _addresses)
              ListTile(
                leading: Icon(
                  address.id == _selectedAddressId ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: address.id == _selectedAddressId ? _primaryOrange : Colors.grey.shade400,
                ),
                onTap: () => Navigator.pop(sheetContext, address.id),
                title: Text('${address.recipientName} • ${address.label ?? 'Address'}'),
                subtitle: Text(address.details, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ListTile(
              leading: const Icon(Icons.add, color: _primaryOrange),
              title: const Text('Add new address', style: TextStyle(color: _primaryOrange)),
              onTap: () => Navigator.pop(sheetContext, -1),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    if (chosen == -1) {
      _addAddress();
    } else {
      setState(() => _selectedAddressId = chosen);
    }
  }

  Future<void> _confirmAndPlaceOrder() async {
    if (_placing) return;
    final cart = context.read<CartProvider>().cart;
    if (_selectedAddressId == null) {
      showMessage(context, 'Please add or select a shipping address.');
      return;
    }
    if (_selectedPaymentId == null) {
      showMessage(context, 'Please add or select a payment method.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm your order'),
        content: Text(
          'Pay ${cart.grandTotal.format()} using your selected payment method?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Place Order'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _placing = true);

    final cartProvider = context.read<CartProvider>();
    try {
      // POST /orders with an Idempotency-Key header.
      final order = await context.read<OrderRepository>().place(
        addressId: _selectedAddressId!,
        paymentMethodId: _selectedPaymentId!,
        deliveryMethod: _selectedDelivery,
        idempotencyKey: _idempotencyKey,
      );
      // The server cleared the cart; reload it.
      await cartProvider.load(deliveryMethod: 'standard');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OrderConfirmationScreen(order: order)),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _placing = false);
      if (error.isConflict) {
        // Stock or coupon changed: show the server message and the fresh cart.
        await cartProvider.load(deliveryMethod: _selectedDelivery);
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Your cart changed'),
            content: Text(_conflictText(error)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Review cart'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      } else if (error.isValidation) {
        final message = error.fieldError('address_id') ??
            error.fieldError('payment_method_id') ??
            error.fieldError('cart') ??
            error.message;
        showMessage(context, message);
        _load();
      } else {
        showApiError(context, error, onRetry: _confirmAndPlaceOrder);
      }
    }
  }

  String _conflictText(ApiException error) {
    final details = error.details;
    final items = details is Map ? details['items'] : null;
    if (items is! List || items.isEmpty) return error.message;
    final lines = items.whereType<Map>().map((item) {
      final available = item['available'];
      return '• ${item['title'] ?? 'An item'}: ${available == 0 ? 'no longer available' : 'only $available left'}';
    });
    return '${error.message}\n\n${lines.join('\n')}';
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final cart = cartProvider.cart;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _loading && _addresses.isEmpty && _paymentMethods.isEmpty
            ? const LoadingView()
            : _error != null
            ? ErrorView(error: _error!, onRetry: _load)
            : !cart.hasSelection
            ? EmptyView(
                icon: Icons.shopping_cart_outlined,
                title: cart.isEmpty ? 'Your cart is empty' : 'No items selected',
                message: cart.isEmpty
                    ? 'Add something to your cart before checking out.'
                    : 'Select the items you want to buy in your cart.',
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        _buildShippingAddressSection(),
                        const SizedBox(height: 16),
                        _buildDeliveryMethodSection(),
                        const SizedBox(height: 16),
                        _buildPaymentMethodSection(),
                        const SizedBox(height: 16),
                        _buildOrderSummarySection(cartProvider),
                      ],
                    ),
                  ),
                  _buildBottomActionBar(cartProvider),
                ],
              ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _addButton(String label, VoidCallback onPressed) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryOrange,
        side: const BorderSide(color: Color(0xFFFFB69B)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  // 1. Shipping Address Section
  Widget _buildShippingAddressSection() {
    final address = _addresses.where((a) => a.id == _selectedAddressId).firstOrNull;
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: _primaryOrange, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Shipping Address',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_addresses.isNotEmpty)
                TextButton(
                  onPressed: _placing ? null : _chooseAddress,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    address == null ? 'Select' : 'Change',
                    style: const TextStyle(
                      color: _primaryOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_addresses.isEmpty) ...[
            Text(
              'You have no saved address yet.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 10),
            _addButton('Add address', _addAddress),
          ] else if (address == null)
            GestureDetector(
              onTap: _chooseAddress,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  'Tap to choose where to deliver',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE8E0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          address.recipientName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        ' • ${address.label ?? 'Address'}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address.details,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.phone,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 2. Delivery Method Section
  Widget _buildDeliveryMethodSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                color: _primaryOrange,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Delivery Method',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDeliveryOption(
            id: 'standard',
            title: 'Standard Delivery',
            subtitle: '3–4 days',
            icon: Icons.local_shipping,
          ),
          const SizedBox(height: 10),
          _buildDeliveryOption(
            id: 'express',
            title: 'Express Delivery',
            subtitle: '1–2 days',
            icon: Icons.bolt,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = _selectedDelivery == id;
    final cart = context.watch<CartProvider>().cart;
    return GestureDetector(
      onTap: _placing ? null : () => _selectDelivery(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryOrange : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isSelected
                  ? _primaryOrange
                  : Colors.grey.shade100,
              radius: 20,
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            // The fee for the selected option comes from the server cart.
            if (isSelected)
              Text(
                cart.shippingTotal.format(),
                style: const TextStyle(
                  color: _primaryOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 3. Payment Method Section
  Widget _buildPaymentMethodSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payment, color: _primaryOrange, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Payment Method',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_paymentMethods.isNotEmpty)
                TextButton(
                  onPressed: _placing ? null : _addPaymentMethod,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Add',
                    style: TextStyle(color: _primaryOrange, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_paymentMethods.isEmpty) ...[
            Text(
              'You have no saved card yet.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 10),
            _addButton('Add card', _addPaymentMethod),
          ] else
            for (final method in _paymentMethods) ...[
              _buildPaymentOption(method),
              if (method != _paymentMethods.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _buildPaymentOption(PaymentMethod method) {
    final bool isSelected = _selectedPaymentId == method.id;
    return GestureDetector(
      onTap: _placing ? null : () => setState(() => _selectedPaymentId = method.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryOrange : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 32,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: PaymentMethodLogo(method: method),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    method.subtitle,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? _primaryOrange : Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }

  // 4. Order Summary Section — every amount comes from the server.
  Widget _buildOrderSummarySection(CartProvider cartProvider) {
    final cart = cartProvider.cart;
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Order Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (cartProvider.loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _primaryOrange),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('${cart.selectedItemCount} items', cart.subtotal.format()),
          const SizedBox(height: 8),
          _buildSummaryRow('Shipping', cart.shippingTotal.format()),
          const SizedBox(height: 8),
          if (cart.coupon != null) ...[
            _buildSummaryRow('Coupon', cart.coupon!.code),
            const SizedBox(height: 8),
          ],
          _buildSummaryRow(
            'Discount',
            '-${cart.discountTotal.format()}',
            isDiscount: true,
          ),
          const Divider(height: 24, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                cart.grandTotal.format(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _primaryOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String title,
    String amount, {
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        Text(
          amount,
          style: TextStyle(
            color: isDiscount ? _primaryOrange : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // Bottom Floating Button
  Widget _buildBottomActionBar(CartProvider cartProvider) {
    final ready = _selectedAddressId != null &&
        _selectedPaymentId != null &&
        !cartProvider.loading &&
        cartProvider.cart.hasSelection &&
        !cartProvider.cart.hasIssues;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryOrange,
            disabledBackgroundColor: _primaryOrange.withValues(alpha: .4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _placing
              ? null
              : ready
              ? _confirmAndPlaceOrder
              : () => showMessage(
                  context,
                  _selectedAddressId == null
                      ? 'Please add or select a shipping address.'
                      : _selectedPaymentId == null
                      ? 'Please add or select a payment method.'
                      : 'Please review your cart first.',
                ),
          child: _placing
              ? const ButtonSpinner()
              : Text(
                  'Place Order  •  ${cartProvider.cart.grandTotal.format()}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
