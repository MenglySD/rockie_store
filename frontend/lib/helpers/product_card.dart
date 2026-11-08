import 'package:flutter/material.dart';
import 'package:rockie_store/helpers/product_image.dart';
import 'package:rockie_store/helpers/selection_sheet.dart';
import 'package:rockie_store/models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          AspectRatio(
            aspectRatio: 1.0,
            child: productImage(product.imageUrl, width: double.infinity),
          ),

          // Product Information
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  product.price.format(),
                  style: const TextStyle(
                    color: Color(0xFFFF4400),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 1),

                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFF4400), size: 14),

                    const SizedBox(width: 3),

                    // Text(
                    //   '\$${product.rating}',
                    //   // '4.9 | 2.5k sold',
                    //   style: TextStyle(
                    //     fontSize: 12,
                    //     color: Colors.grey.shade700,
                    //   ),
                    // ),
                    Text(
                      '${product.rating.toStringAsFixed(1)} | ${product.sold} sold',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    const Spacer(),

                    IconButton(
                      // Pick color/size first: the cart needs a variant ID.
                      onPressed: product.inStock
                          ? () => showProductOptions(context, product)
                          : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      icon: Image.asset(
                        'assets/images/icon/Vector.png',
                        width: 20,
                        height: 20,
                        color: product.inStock ? null : Colors.grey.shade400,
                      ),
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
