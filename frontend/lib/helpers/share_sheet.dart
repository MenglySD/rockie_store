import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Bottom sheet matching the "Share" screen — share targets, app shortcuts,
/// and a Cancel action.
class ShareSheet extends StatelessWidget {
  const ShareSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        color: mainColor,
        padding: EdgeInsets.only(top: 10, bottom: MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GrabHandle(),
            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 18),
            const _ShareTargetsRow(),
            const SizedBox(height: 18),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 18),
            const _AppShortcutsRow(),
            const SizedBox(height: 24),
            const _CancelButton(),
          ],
        ),
      ),
    );
  }
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
    );
  }
}

class _ShareTargetsRow extends StatelessWidget {
  const _ShareTargetsRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ShareButton(
            label: 'Copy link',
            backgroundColor: mainColor,
            icon: Icons.link,
            onTap: () {},
          ),
          _ShareButton(
            label: 'Save image',
            backgroundColor: mainColor,
            icon: Icons.download,
            onTap: () {},
          ),
          _ShareButton(
            label: 'Facebook',
            backgroundColor: mainColor,
            icon: Icons.facebook,
            onTap: () {},
          ),
          _ShareButton(
            label: 'Messenger',
            backgroundColor: mainColor,
            icon: Icons.chat_bubble,
            onTap: () {},
          ),
          _ShareButton(
            label: 'Telegram',
            backgroundColor: mainColor,
            icon: Icons.send,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _AppShortcutsRow extends StatelessWidget {
  const _AppShortcutsRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ShortcutButton(
            label: 'Home',
            icon: Icons.home_outlined,
            onTap: () {},
          ),
          _ShortcutButton(
            label: 'Account',
            icon: Icons.person_outline,
            onTap: () {},
          ),
          _ShortcutButton(
            label: 'Cart',
            icon: Icons.shopping_cart_outlined,
            onTap: () {},
          ),
          _ShortcutButton(
            label: 'Orders',
            icon: Icons.assignment_outlined,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final IconData icon;
  final VoidCallback onTap;

  const _ShareButton({
    required this.label,
    required this.backgroundColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Normal label
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ShortcutButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.shade300,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.black87,
              size: 24,
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Normal label
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: mainColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ),
      ),
    );
  }
}
