import 'package:flutter/material.dart';
import 'package:flutter_svg_provider/flutter_svg_provider.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/theme/app_colors.dart';
import 'package:rockie_store/models/menu_item.dart';
import 'package:rockie_store/provider/home_provider.dart';
import 'package:rockie_store/screen/account_screen.dart';
import 'package:rockie_store/screen/shop_cart_screen.dart';
import 'package:rockie_store/screen/category_screen.dart';
import 'package:rockie_store/screen/contact_screen.dart';
import 'package:rockie_store/screen/shop_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<MenuItem> _menus = [
    MenuItem(
      label: 'Home',
      icon: 'assets/images/svg/Icon-1.svg',
      selectedIcon: 'assets/images/svg/home.svg',
    ),
    MenuItem(
      label: 'Category',
      icon: 'assets/images/svg/Icon-2.svg',
      selectedIcon: 'assets/images/svg/Layout.svg',
    ),
    MenuItem(
      label: 'Contact',
      icon: 'assets/images/svg/elements.svg',
      selectedIcon: 'assets/images/svg/chat.svg',
    ),
    MenuItem(
      label: 'Cart',
      icon: 'assets/images/svg/Shopping Cart.svg',
      selectedIcon: 'assets/images/svg/Shopping.svg',
    ),
    MenuItem(
      label: 'Account',
      icon: 'assets/images/svg/Icon.svg',
      selectedIcon: 'assets/images/svg/User.svg',
    ),
  ];

  final List<Widget> _pages = [
    ShopScreen(),
    CategoryScreen(),
    ContactScreen(),
    ShopCartScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<HomeProvider>(
        builder: (_, value, _) =>
            IndexedStack(index: value.currentIndex, children: [..._pages]),
      ),
      bottomNavigationBar: Consumer<HomeProvider>(
        builder: (_, provider, _) => BottomNavigationBar(
          currentIndex: provider.currentIndex,
          onTap: (index) {
            provider.onTap(index);
          },
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: mainColor,
          unselectedItemColor: Colors.grey.shade600,
          showSelectedLabels: true,
          items: [
            for (int index = 0; index < _menus.length; index++)
              BottomNavigationBarItem(
                icon: ImageIcon(
                  Svg(
                    provider.currentIndex == index
                        ? _menus[index].selectedIcon
                        : _menus[index].icon,
                  ),
                ),
                label: _menus[index].label,
              ),
          ],
        ),
      ),
    );
  }
}
