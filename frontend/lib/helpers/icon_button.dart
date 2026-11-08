import 'package:flutter/material.dart';

/// Small circular semi-transparent button, used for the header icons
/// overlaid on top of images (back, search, cart, more, close, arrows).
/// Circular icon button
class CircleIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xff191C1E).withOpacity(0.50),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: icon,
          ),
        ),
      ),
    );
  }
}
