import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/product_image.dart';
import 'package:rockie_store/models/user.dart';
import 'package:rockie_store/provider/auth_provider.dart';
import 'package:rockie_store/services/api_exception.dart';
import 'package:rockie_store/theme/app_colors.dart';

/// Profile photo (POST/DELETE /me/avatar) plus name and gender (PATCH /me).
/// Password changes live in Settings.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverErrors = ServerErrors();
  late final TextEditingController _nameController;
  Gender? _gender;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _gender = user?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    _serverErrors.clear();
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await context.read<AuthProvider>().updateProfile(
        name: _nameController.text.trim(),
        gender: _gender,
      );
      if (!mounted) return;
      showMessage(context, 'Profile updated');
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (!mounted) return;
      final shown = error.isValidation &&
          _serverErrors.apply(error, _formKey, fields: const ['name', 'gender']);
      if (!shown) showApiError(context, error, onRetry: _save);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Gallery / camera / remove. The new photo is uploaded right away.
  Future<void> _changePhoto() async {
    if (_uploadingPhoto) return;
    final hasPhoto = context.read<AuthProvider>().user?.avatarUrl != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove photo', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'remove') return _runPhotoAction(() => context.read<AuthProvider>().removeAvatar(), 'Photo removed');

    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open the photos. Check the app permissions.');
      return;
    }
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await _runPhotoAction(
      () => context.read<AuthProvider>().updateAvatar(bytes, file!.name),
      'Profile photo updated',
    );
  }

  Future<void> _runPhotoAction(Future<void> Function() action, String success) async {
    setState(() => _uploadingPhoto = true);
    try {
      await action();
      if (mounted) showMessage(context, success);
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final avatar = networkImageProvider(user?.avatarUrl);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: GestureDetector(
                  onTap: _saving ? null : _changePhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white,
                        backgroundImage: avatar ?? const AssetImage('assets/images/profile.png'),
                        child: _uploadingPhoto
                            ? Container(
                                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: mainColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => _serverErrors.clear('name'),
                    validator: (value) {
                      final serverError = _serverErrors.of('name');
                      if (serverError != null) return serverError;
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return 'Please enter your name';
                      if (name.length > 255) return 'Name is too long';
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<Gender?>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<Gender?>(value: null, child: Text('Not set')),
                      for (final gender in Gender.values)
                        DropdownMenuItem<Gender?>(value: gender, child: Text(gender.label)),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _gender = value;
                            _serverErrors.clear('gender');
                          }),
                    validator: (_) => _serverErrors.of('gender'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving || _uploadingPhoto ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving ? const ButtonSpinner() : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
