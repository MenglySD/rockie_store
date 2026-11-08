import 'package:flutter/material.dart';
import 'package:rockie_store/helpers/session.dart';
import 'package:rockie_store/screen/address_screen.dart';
import 'package:rockie_store/screen/change_password_screen.dart';
import 'package:rockie_store/screen/contact_screen.dart';
import 'package:rockie_store/screen/notification_screen.dart';
import 'package:rockie_store/screen/payment_methods_screen.dart';
import 'package:rockie_store/theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSectionHeader('Account and security'),
                _buildListItem('My addresses', onTap: () => _open(context, const AddressScreen())),
                _buildListItem('Account and security', onTap: () => _open(context, const ChangePasswordScreen())),
                _buildListItem('Payment settings', onTap: () => _open(context, const PaymentMethodsScreen())),
                _buildListItem('Country and region/language/currency'),

                _buildThickDivider(),

                _buildSectionHeader('Function'),
                _buildListItem('General'),
                _buildListItem('Notifications', onTap: () => _open(context, const NotificationScreen())),
                _buildListItem('Privacy'),

                _buildThickDivider(),

                _buildSectionHeader('About'),
                _buildListItem('Help and feedback', onTap: () => _open(context, const ContactScreen())),
                _buildListItem('About Nexus Retail'),
                _buildListItem('Legal Agreement'),
              ],
            ),
          ),
          _buildBottomSection(context),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildListItem(String title, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Color(0xFFB0B0B0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThickDivider() {
    return Container(
      height: 10,
      color: const Color(
        0xFFF4F5F9,
      ), // Faint blue-grey divider matching the design
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F5F9),
        border: Border(top: BorderSide(color: Color(0xFFE2E3E8), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => logout(context),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: mainColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Switch account',
                style: TextStyle(
                  color: mainColor, // Orange text
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => logout(context),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.black54),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
