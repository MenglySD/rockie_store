import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/provider/auth_provider.dart';
import 'package:rockie_store/repositories/profile_repository.dart';
import 'package:rockie_store/screen/notification_screen.dart';
import 'package:rockie_store/theme/app_colors.dart';


class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final subjectController = TextEditingController();
  final messageController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    nameController.text = user?.name ?? '';
    emailController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    subjectController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_sending) return;
    final email = emailController.text.trim();
    if (nameController.text.trim().isEmpty ||
        email.isEmpty ||
        messageController.text.trim().isEmpty) {
      showMessage(context, "Fill in your name, email, and message.");
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      showMessage(context, 'Please enter a valid email address.');
      return;
    }
    if (messageController.text.trim().length < 5) {
      showMessage(context, 'Please write at least 5 characters.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await context.read<ProfileRepository>().sendSupportMessage(
        name: nameController.text.trim(),
        email: email,
        subject: subjectController.text.trim().isEmpty ? null : subjectController.text.trim(),
        message: messageController.text.trim(),
      );
      if (!mounted) return;
      subjectController.clear();
      messageController.clear();
      showMessage(context, 'Thanks! Our support team will get back to you soon.');
    } catch (error) {
      if (mounted) showApiError(context, error, onRetry: _handleSend);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Contact Us",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "We're here to help. Send us a message and we'll "
                      "respond as soon as possible.",
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFormCard(),
                    const SizedBox(height: 20),
                    const Text(
                      "Direct Contact",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const ContactInfoTile(
                      icon: Icons.mail_outline,
                      title: "Email Support",
                      subtitle: "support@rockiestore.com",
                    ),
                    const SizedBox(height: 10),
                    const ContactInfoTile(
                      icon: Icons.call_outlined,
                      title: "Phone Support",
                      subtitle: "+885 93 8888 173",
                    ),
                    const SizedBox(height: 10),
                    const ContactInfoTile(
                      icon: Icons.location_on_outlined,
                      title: "Headquarters",
                      subtitle:
                          "No. 86A, Street 110,\n"
                          "Russian Federation Blvd (110), Phnom Penh",
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // Back arrow only when opened from another page (Settings),
    // not as the bottom navigation tab.
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return Padding(
      padding: EdgeInsets.fromLTRB(canPop ? 4 : 16, 12, 16, 4),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          Image.asset('assets/images/logo.png', width: 105, height: 30),
          const Spacer(),
          IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black, size: 24),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationScreen(),
              ),
            );
          },
        ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FormLabel("Full Name"),
          const SizedBox(height: 6),
          _RoundedField(controller: nameController, hint: "Name"),
          const SizedBox(height: 16),
          const FormLabel("Email Address"),
          const SizedBox(height: 6),
          _RoundedField(
            controller: emailController,
            hint: "email",
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          const FormLabel("Subject"),
          const SizedBox(height: 6),
          _RoundedField(controller: subjectController, hint: "Order Inquiry"),
          const SizedBox(height: 16),
          const FormLabel("Message"),
          const SizedBox(height: 6),
          _RoundedField(
            controller: messageController,
            hint: "How can we help you?",
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _handleSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: _sending
                  ? const ButtonSpinner()
                  : const Text(
                      "Send Message",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class FormLabel extends StatelessWidget {
  final String text;
  const FormLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }
}

class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _RoundedField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final isMultiline = maxLines > 1;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        filled: true,
        fillColor: Color(0xffF1F5F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isMultiline ? 16 : 24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Reusable row for the "Direct Contact" section.
class ContactInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const ContactInfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: mainColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: mainColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
