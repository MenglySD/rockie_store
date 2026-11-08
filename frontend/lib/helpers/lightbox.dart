import 'package:flutter/material.dart';

import 'icon_button.dart';
import 'product_image.dart';

/// Full-screen image viewer opened by tapping a customer feedback photo.
/// Shows a "current / total" index and lets the user swipe between photos.
class Lightbox extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const Lightbox({super.key, required this.images, required this.initialIndex});

  @override
  State<Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<Lightbox> {
  late int _index;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: widget.images.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => GestureDetector(
                      onTap: () {}, // absorb tap so it doesn't close on image
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: productImage(
                          widget.images[i],
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${_index + 1} / ${widget.images.length}",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 12,
                child: CircleIconButton(
                  icon: Image.asset('assets/images/icon/Shopping Cart.png'),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
