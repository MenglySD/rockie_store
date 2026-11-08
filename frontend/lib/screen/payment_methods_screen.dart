import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/models/payment_method.dart';
import 'package:rockie_store/repositories/payment_method_repository.dart';
import 'package:rockie_store/services/api_exception.dart';
import 'package:rockie_store/theme/app_colors.dart';

/// Saved cards from /payment-methods. New users have none and nothing
/// becomes default unless the user picks "Set as default". To change a card,
/// remove it and add it again.
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<PaymentMethod> _methods = const [];
  bool _loading = true;
  Object? _error;
  final Set<int> _busyIds = {};

  PaymentMethodRepository get _repository => context.read<PaymentMethodRepository>();

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
    try {
      final methods = await _repository.list();
      if (mounted) setState(() => _methods = methods);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final saved = await showPaymentMethodForm(context);
    if (saved != null && mounted) {
      showMessage(context, 'Card added');
      _load();
    }
  }

  Future<void> _setDefault(PaymentMethod method) =>
      _run(method, () => _repository.setDefault(method.id), '${method.label} set as default');

  Future<void> _remove(PaymentMethod method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove payment method?'),
        content: Text('${method.label} will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(method, () => _repository.delete(method.id), 'Payment method removed');
  }

  Future<void> _run(PaymentMethod method, Future<void> Function() action, String success) async {
    if (_busyIds.contains(method.id)) return;
    setState(() => _busyIds.add(method.id));
    try {
      await action();
      if (!mounted) return;
      showMessage(context, success);
      await _load();
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _busyIds.remove(method.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F9),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Payment Methods', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _methods.isEmpty) return const LoadingView();
    if (_error != null && _methods.isEmpty) return ErrorView(error: _error!, onRetry: _load);
    if (_methods.isEmpty) {
      return EmptyView(
        icon: Icons.credit_card_off_outlined,
        title: 'No cards yet',
        message: 'Add a card to pay for your orders.',
        actionLabel: 'Add card',
        onAction: _add,
      );
    }
    return RefreshIndicator(
      color: mainColor,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text('Saved methods', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final method in _methods) ...[
            _MethodCard(
              method: method,
              busy: _busyIds.contains(method.id),
              onDefault: () => _setDefault(method),
              onRemove: () => _remove(method),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add, size: 19),
            label: const Text('Add Card'),
            style: OutlinedButton.styleFrom(
              foregroundColor: mainColor,
              side: const BorderSide(color: Color(0xFFFFB69B)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'We only keep the card brand, last 4 digits and expiry date. '
            'Your full card number and security code are never sent or stored.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8A8583), fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Opens the "Add card" sheet. Returns the saved card, or null if cancelled.
/// Also used by checkout.
Future<PaymentMethod?> showPaymentMethodForm(BuildContext context) {
  return showModalBottomSheet<PaymentMethod>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CardSheet(),
  );
}

/// Logo or icon for a payment method, used here and on checkout.
class PaymentMethodLogo extends StatelessWidget {
  final PaymentMethod method;
  const PaymentMethodLogo({super.key, required this.method});

  @override
  Widget build(BuildContext context) {
    final asset = method.logoAsset;
    if (asset != null) {
      return Image.asset(asset, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.credit_card, color: mainColor));
    }
    return Icon(method.isCard ? Icons.credit_card : Icons.payments_outlined, color: mainColor);
  }
}

class _MethodCard extends StatelessWidget {
  final PaymentMethod method;
  final bool busy;
  final VoidCallback onDefault;
  final VoidCallback onRemove;

  const _MethodCard({
    required this.method,
    required this.busy,
    required this.onDefault,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 42,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F8), borderRadius: BorderRadius.circular(9)),
            child: PaymentMethodLogo(method: method),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(method.label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                    if (method.isDefault) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFFF0E9), borderRadius: BorderRadius.circular(9)),
                        child: const Text('DEFAULT', style: TextStyle(color: mainColor, fontSize: 8, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  method.subtitle,
                  style: TextStyle(fontSize: 11, color: method.isExpired ? Colors.red : const Color(0xFF77716F)),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: mainColor))
          else
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert, color: Color(0xFF77716F)),
              onSelected: (value) {
                if (value == 'default') onDefault();
                if (value == 'remove') onRemove();
              },
              itemBuilder: (_) => [
                if (!method.isDefault) const PopupMenuItem(value: 'default', child: Text('Set as default')),
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
        ],
      ),
    );
  }
}

/// "Add card" form. The card number and security code are only checked
/// here; the API receives the brand, last 4 digits and expiry date.
class _CardSheet extends StatefulWidget {
  const _CardSheet();

  @override
  State<_CardSheet> createState() => _CardSheetState();
}

class _CardSheetState extends State<_CardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _serverErrors = ServerErrors();
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  bool _isDefault = false;
  bool _saving = false;

  String get _digits => _number.text.replaceAll(' ', '');
  String? get _brand => detectCardBrand(_digits);
  int get _cvvLength => _brand == 'amex' ? 4 : 3;

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  /// "MM/YY" → (month, year), or null when the format is wrong.
  (int, int)? _parseExpiry(String value) {
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(value);
    if (match == null) return null;
    return (int.parse(match.group(1)!), 2000 + int.parse(match.group(2)!));
  }

  String? _validateNumber(String? _) {
    final serverError = _serverErrors.of('last4') ?? _serverErrors.of('brand');
    if (serverError != null) return serverError;
    final digits = _digits;
    if (digits.isEmpty) return 'Please enter the card number';
    if (digits.length < 13 || digits.length > 19) return 'Enter a valid card number';
    return null;
  }

  String? _validateExpiry(String? value) {
    final serverError = _serverErrors.of('exp_month') ?? _serverErrors.of('exp_year');
    if (serverError != null) return serverError;
    final parsed = _parseExpiry(value?.trim() ?? '');
    if (parsed == null) return 'Use MM/YY';
    final (month, year) = parsed;
    if (month < 1 || month > 12) return 'Month must be 01–12';
    final now = DateTime.now();
    // Valid until the end of the expiry month.
    if (DateTime(year, month + 1).isBefore(DateTime(now.year, now.month + 1))) {
      return 'This card has expired';
    }
    if (year > now.year + 20) return 'Check the year';
    return null;
  }

  String? _validateCvv(String? value) {
    final cvv = value?.trim() ?? '';
    if (cvv.isEmpty) return 'Required';
    if (cvv.length != _cvvLength) return '$_cvvLength digits';
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    _serverErrors.clear();
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final digits = _digits;
    final (month, year) = _parseExpiry(_expiry.text.trim())!;
    final input = PaymentMethodInput(
      brand: _brand,
      last4: digits.substring(digits.length - 4),
      expMonth: month,
      expYear: year,
      isDefault: _isDefault,
    );
    final repository = context.read<PaymentMethodRepository>();
    try {
      final saved = await repository.create(input);
      if (mounted) Navigator.pop(context, saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      final shown = error.isValidation &&
          _serverErrors.apply(error, _formKey, fields: const ['brand', 'last4', 'exp_month', 'exp_year']);
      if (!shown) showApiError(context, error, onRetry: _save);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = _brand;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Card', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _number,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.creditCardNumber],
                    inputFormatters: [_CardNumberFormatter()],
                    onChanged: (_) => setState(() {
                      _serverErrors.clear('last4');
                      _serverErrors.clear('brand');
                    }),
                    validator: _validateNumber,
                    decoration: _decoration('Card number').copyWith(
                      hintText: '1234 5678 9012 3456',
                      prefixIcon: const Icon(Icons.credit_card),
                      suffixText: brand == null ? null : cardBrandName(brand),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expiry,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.creditCardExpirationDate],
                          inputFormatters: [_ExpiryFormatter()],
                          onChanged: (_) {
                            _serverErrors.clear('exp_month');
                            _serverErrors.clear('exp_year');
                          },
                          validator: _validateExpiry,
                          decoration: _decoration('Expiry date').copyWith(hintText: 'MM/YY'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _cvv,
                          enabled: !_saving,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.creditCardSecurityCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          validator: _validateCvv,
                          decoration: _decoration('Security code').copyWith(hintText: brand == 'amex' ? '1234' : '123'),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: mainColor,
                    title: const Text('Set as default payment method', style: TextStyle(fontSize: 14)),
                    value: _isDefault,
                    onChanged: _saving ? null : (value) => setState(() => _isDefault = value),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: Color(0xFF8A8583)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Only the brand, last 4 digits and expiry date are saved.',
                          style: TextStyle(color: Color(0xFF8A8583), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: mainColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                      child: _saving
                          ? const ButtonSpinner()
                          : const Text('Save Card', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFFAFAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE7E7E7))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE7E7E7))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: mainColor)),
      );
}

/// Digits only, max 19, shown in groups of 4: "4242 4242 4242 4242".
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 19) digits = digits.substring(0, 19);
    final groups = [
      for (var i = 0; i < digits.length; i += 4) digits.substring(i, i + 4 > digits.length ? digits.length : i + 4),
    ];
    final text = groups.join(' ');
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Digits only, shown as "MM/YY".
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    final text = digits.length > 2 ? '${digits.substring(0, 2)}/${digits.substring(2)}' : digits;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

