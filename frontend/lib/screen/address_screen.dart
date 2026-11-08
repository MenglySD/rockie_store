import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/models/address.dart';
import 'package:rockie_store/repositories/address_repository.dart';
import 'package:rockie_store/services/api_exception.dart';
import 'package:rockie_store/theme/app_colors.dart';

/// Saved addresses from /addresses. New users have none, and nothing is
/// made default automatically — only when the user chooses "Set as default".
class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  List<Address> _addresses = const [];
  bool _loading = true;
  Object? _error;
  final Set<int> _busyIds = {};

  AddressRepository get _repository => context.read<AddressRepository>();

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
      final addresses = await _repository.list();
      if (mounted) setState(() => _addresses = addresses);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editAddress([Address? address]) async {
    final saved = await showAddressForm(context, address: address);
    if (saved != null && mounted) {
      showMessage(context, address == null ? 'Address added' : 'Address updated');
      _load();
    }
  }

  Future<void> _makeDefault(Address address) async {
    await _run(address, () => _repository.setDefault(address.id), 'Default address updated');
  }

  Future<void> _delete(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('${address.label ?? 'This address'} will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(address, () => _repository.delete(address.id), 'Address deleted');
  }

  Future<void> _run(Address address, Future<void> Function() action, String success) async {
    if (_busyIds.contains(address.id)) return;
    setState(() => _busyIds.add(address.id));
    try {
      await action();
      if (!mounted) return;
      showMessage(context, success);
      await _load();
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _busyIds.remove(address.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Addresses', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: _buildBody(),
      bottomNavigationBar: _addresses.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _editAddress(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Address'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading && _addresses.isEmpty) return const LoadingView();
    if (_error != null && _addresses.isEmpty) return ErrorView(error: _error!, onRetry: _load);
    if (_addresses.isEmpty) {
      return EmptyView(
        icon: Icons.location_off_outlined,
        title: 'No saved addresses yet',
        message: 'Add an address so we know where to deliver your orders.',
        actionLabel: 'Add address',
        onAction: () => _editAddress(),
      );
    }
    return RefreshIndicator(
      color: mainColor,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _addresses.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final address = _addresses[index];
          return _AddressCard(
            address: address,
            busy: _busyIds.contains(address.id),
            onEdit: () => _editAddress(address),
            onDefault: () => _makeDefault(address),
            onDelete: () => _delete(address),
          );
        },
      ),
    );
  }
}

/// Opens the add/edit sheet. Returns the saved address, or null if cancelled.
/// Also used by checkout.
Future<Address?> showAddressForm(BuildContext context, {Address? address}) {
  return showModalBottomSheet<Address>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddressForm(address: address),
  );
}

class _AddressCard extends StatelessWidget {
  final Address address;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDefault;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.busy,
    required this.onEdit,
    required this.onDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: mainColor, size: 21),
              const SizedBox(width: 8),
              Text(address.label ?? 'Address', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (address.isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFFF0E9), borderRadius: BorderRadius.circular(10)),
                  child: const Text('DEFAULT', style: TextStyle(color: mainColor, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ],
              const Spacer(),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: mainColor),
                )
              else
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_horiz, color: Colors.black54),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'default') onDefault();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    if (!address.isDefault) const PopupMenuItem(value: 'default', child: Text('Set as default')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(address.recipientName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(address.phone, style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 13)),
          const SizedBox(height: 8),
          Text(address.details, style: const TextStyle(color: Color(0xFF555555), fontSize: 13, height: 1.45)),
        ],
      ),
    );
  }
}

class _AddressForm extends StatefulWidget {
  final Address? address;
  const _AddressForm({this.address});

  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  static const _labels = ['Home', 'Work', 'Other'];

  final _formKey = GlobalKey<FormState>();
  final _serverErrors = ServerErrors();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _line1;
  late final TextEditingController _city;
  late String _label;
  late bool _isDefault;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    _name = TextEditingController(text: a?.recipientName ?? '');
    _phone = TextEditingController(text: a?.phone ?? '');
    _line1 = TextEditingController(text: a?.line1 ?? '');
    _city = TextEditingController(text: a?.city ?? '');
    _label = _labels.contains(a?.label) ? a!.label! : 'Home';
    // Off for new addresses: the user decides.
    _isDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _line1, _city]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    _serverErrors.clear();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final input = AddressInput(
      label: _label,
      recipientName: _name.text.trim(),
      phone: _phone.text.trim(),
      line1: _line1.text.trim(),
      city: _city.text.trim(),
      isDefault: _isDefault,
    );
    final repository = context.read<AddressRepository>();
    try {
      final saved = widget.address == null
          ? await repository.create(input)
          : await repository.update(widget.address!.id, input);
      if (mounted) Navigator.pop(context, saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      final shown = error.isValidation &&
          _serverErrors.apply(error, _formKey, fields: const ['label', 'recipient_name', 'phone', 'line1', 'city']);
      if (!shown) showApiError(context, error, onRetry: _save);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 18),
                  Text(widget.address == null ? 'Add New Address' : 'Edit Address', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 18),
                  _field(_name, 'Full name', 'recipient_name', maxLength: 255),
                  const SizedBox(height: 12),
                  _field(
                    _phone,
                    'Phone number',
                    'phone',
                    keyboard: TextInputType.phone,
                    extra: (value) => RegExp(r'^\+?[0-9 ()\-]{6,30}$').hasMatch(value) ? null : 'Enter a valid phone number',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _label,
                    decoration: _decoration('Address label'),
                    items: _labels.map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
                    onChanged: _saving ? null : (value) => setState(() => _label = value ?? 'Home'),
                  ),
                  const SizedBox(height: 12),
                  _field(_line1, 'Street', 'line1', maxLength: 255),
                  const SizedBox(height: 12),
                  _field(_city, 'City', 'city', maxLength: 100),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: mainColor,
                    title: const Text('Set as default address', style: TextStyle(fontSize: 14)),
                    value: _isDefault,
                    onChanged: _saving ? null : (value) => setState(() => _isDefault = value),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: mainColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                      child: _saving
                          ? const ButtonSpinner()
                          : const Text('Save Address', style: TextStyle(fontWeight: FontWeight.w600)),
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

  Widget _field(
    TextEditingController controller,
    String hint,
    String field, {
    TextInputType? keyboard,
    int maxLines = 1,
    bool required = true,
    int? maxLength,
    String? Function(String value)? extra,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      enabled: !_saving,
      onChanged: (_) => _serverErrors.clear(field),
      validator: (raw) {
        final serverError = _serverErrors.of(field);
        if (serverError != null) return serverError;
        final value = raw?.trim() ?? '';
        if (value.isEmpty) return required ? 'Please enter ${hint.toLowerCase()}' : null;
        if (maxLength != null && value.length > maxLength) return 'Maximum $maxLength characters';
        return extra?.call(value);
      },
      decoration: _decoration(hint),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        labelText: hint,
        filled: true,
        fillColor: const Color(0xFFFAFAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE7E7E7))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE7E7E7))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: mainColor)),
      );
}
