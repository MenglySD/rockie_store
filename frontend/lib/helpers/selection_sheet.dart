import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/product_image.dart';
import 'package:rockie_store/provider/cart_provider.dart';
import 'package:rockie_store/repositories/product_repository.dart';
import 'package:rockie_store/screen/cart_screen.dart';
import 'package:rockie_store/screen/checkout_screen.dart';
import 'package:rockie_store/services/api_exception.dart';
import '../models/product.dart';

/// Opens the color/size/quantity sheet. List items have no variants, so the
/// product detail is loaded first.
Future<void> showProductOptions(BuildContext context, Product product) async {
  var detailed = product;
  if (product.variants.isEmpty) {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingView(),
    );
    try {
      detailed = await context.read<ProductRepository>().product(product.id);
    } catch (error) {
      navigator.pop();
      if (context.mounted) showApiError(context, error);
      return;
    }
    navigator.pop();
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SelectionSheet(product: detailed),
  );
}

class SelectionSheet extends StatefulWidget {
  final Product product;

  const SelectionSheet({super.key, required this.product});

  @override
  State<SelectionSheet> createState() => _SelectionSheetState();
}

class _SelectionSheetState extends State<SelectionSheet> {
  int quantity = 1;
  String? selectedColor;
  String? selectedSize;
  bool _submitting = false;

  Product get product => widget.product;

  @override
  void initState() {
    super.initState();
    // Preselect the first in-stock combination.
    final firstInStock = product.variants.where((v) => v.inStock).firstOrNull ??
        product.variants.firstOrNull;
    selectedColor = firstInStock?.color;
    selectedSize = firstInStock?.size;
  }

  ProductVariant? get _variant =>
      product.variantFor(color: selectedColor, size: selectedSize);

  int get _maxQuantity => _variant?.maxQuantity ?? 0;

  bool _sizeAvailable(String size) =>
      product.variantFor(color: selectedColor, size: size)?.inStock ?? false;

  bool _colorAvailable(String color) =>
      product.variants.any((v) => v.color == color && v.inStock);

  void _selectColor(String color) {
    setState(() {
      selectedColor = color;
      // Keep the size if it exists for this color, otherwise pick one that does.
      if (!_sizeAvailable(selectedSize ?? '')) {
        selectedSize = product.variants
            .where((v) => v.color == color && v.inStock)
            .firstOrNull
            ?.size ?? selectedSize;
      }
      quantity = quantity.clamp(1, _maxQuantity < 1 ? 1 : _maxQuantity);
    });
  }

  void _selectSize(String size) {
    setState(() {
      selectedSize = size;
      quantity = quantity.clamp(1, _maxQuantity < 1 ? 1 : _maxQuantity);
    });
  }

  Future<void> _submit({required bool buyNow}) async {
    final variant = _variant;
    if (variant == null || !variant.inStock || _submitting) return;
    setState(() => _submitting = true);

    final navigator = Navigator.of(context);
    try {
      // POST /cart/items { product_variant_id, quantity }
      final cart = context.read<CartProvider>();
      if (buyNow) {
        await cart.buyNow(productVariantId: variant.id, quantity: quantity);
      } else {
        await cart.addItem(productVariantId: variant.id, quantity: quantity);
      }
      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => buyNow ? const CheckoutScreen() : const CartScreen(),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showApiError(context, error, onRetry: () => _submit(buyNow: buyNow));
    }
  }

  @override
  Widget build(BuildContext context) {
    final variant = _variant;
    final inStock = variant?.inStock ?? false;
    final hasColors = product.colors.isNotEmpty;
    final hasSizes = product.sizes.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Selection Details & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Select: ${[selectedColor, selectedSize].whereType<String>().join(' / ')}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Product Details (Image, Price, Discount)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: productImage(product.imageUrl, width: 80, height: 80),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          product.price.format(),
                          style: const TextStyle(
                            color: Colors.deepOrange,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (product.discountPct > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-${product.discountPct}%',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (product.hasDiscount)
                      Text(
                        product.originalPrice.format(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quantity Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quantity',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      variant == null
                          ? 'Choose an option'
                          : inStock
                          ? '(Purchase limit: ${variant.purchaseLimit} pcs) ${variant.stock} in stock'
                          : 'Out of stock',
                      style: TextStyle(
                        color: inStock ? Colors.grey : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        onPressed: quantity > 1 && !_submitting
                            ? () => setState(() => quantity--)
                            : null,
                      ),
                      Text(
                        '$quantity',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: quantity < _maxQuantity && !_submitting
                            ? () => setState(() => quantity++)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Color Selector
            if (hasColors) ...[
              Text(
                'Color (${product.colors.length})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: product.colors.map((color) {
                  final isSelected = color == selectedColor;
                  final available = _colorAvailable(color);
                  return GestureDetector(
                    onTap: _submitting ? null : () => _selectColor(color),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.deepOrange : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            color,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : available
                                  ? Colors.black
                                  : Colors.grey,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              decoration: available ? null : TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Size Selector
            if (hasSizes) ...[
              const Text('Size', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: product.sizes.map((size) {
                  final isSelected = selectedSize == size;
                  final available = _sizeAvailable(size);
                  return GestureDetector(
                    onTap: _submitting ? null : () => _selectSize(size),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.deepOrange
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        size,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : available
                              ? Colors.black
                              : Colors.grey,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          decoration: available ? null : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.deepOrange),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: inStock && !_submitting ? () => _submit(buyNow: false) : null,
                    child: _submitting
                        ? const ButtonSpinner(color: Colors.deepOrange)
                        : const Text(
                            'Add to cart',
                            style: TextStyle(color: Colors.deepOrange),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: inStock && !_submitting ? () => _submit(buyNow: true) : null,
                    child: const Text(
                      'Buy now',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
