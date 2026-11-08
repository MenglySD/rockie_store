import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/repositories/product_repository.dart';
import 'package:rockie_store/services/api_exception.dart';
import 'package:rockie_store/theme/app_colors.dart';

/// POST /products/{id}/reviews with a rating, text and up to 5 photos.
/// The server only accepts reviews from users who ordered the product,
/// one per product.
class ProductReviewScreen extends StatefulWidget {
  final int productId;
  final String productTitle;

  const ProductReviewScreen({super.key, required this.productId, required this.productTitle});

  @override
  State<ProductReviewScreen> createState() => _ProductReviewScreenState();
}

class _ProductReviewScreenState extends State<ProductReviewScreen> {
  static const _maxPhotos = 5;

  final _reviewController = TextEditingController();
  final List<_PickedPhoto> _photos = [];
  int _rating = 5;
  bool _submitting = false;
  String? _error;
  String? _photoError;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0 || _submitting) return;

    final source = kIsWeb
        ? ImageSource.gallery
        : await showModalBottomSheet<ImageSource>(
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
                    title: Text('Choose from gallery (up to $remaining)'),
                    onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Take a photo'),
                    onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final List<XFile> files;
    try {
      if (source == ImageSource.camera) {
        final file = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
        files = file == null ? const [] : [file];
      } else if (remaining == 1) {
        // pickMultiImage needs a limit of at least 2.
        final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
        files = file == null ? const [] : [file];
      } else {
        files = await picker.pickMultiImage(limit: remaining, maxWidth: 1600, imageQuality: 85);
      }
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open the photos. Check the app permissions.');
      return;
    }
    if (files.isEmpty) return;

    final picked = <_PickedPhoto>[];
    for (final file in files.take(remaining)) {
      picked.add(_PickedPhoto(await file.readAsBytes(), file.name));
    }
    if (!mounted) return;
    setState(() {
      _photos.addAll(picked);
      _photoError = files.length > remaining ? 'You can add up to $_maxPhotos photos.' : null;
    });
  }

  Future<void> _submitReview() async {
    final text = _reviewController.text.trim();
    if (text.length < 3 || _submitting) {
      setState(() => _error = 'Please write at least 3 characters.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _photoError = null;
    });
    try {
      await context.read<ProductRepository>().submitReview(
        widget.productId,
        rating: _rating,
        body: text,
        photos: [for (final photo in _photos) ReviewPhoto(photo.bytes, photo.filename)],
      );
      if (!mounted) return;
      showMessage(context, 'Thanks for sharing your review!');
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isValidation) {
        final photoError = error.fieldErrors.entries
            .where((entry) => entry.key == 'images' || entry.key.startsWith('images.'))
            .map((entry) => entry.value.first)
            .firstOrNull;
        setState(() {
          _photoError = photoError;
          _error = error.fieldError('body') ?? error.fieldError('rating') ?? (photoError == null ? error.message : null);
        });
      } else {
        // 403: the user has not ordered this product.
        showApiError(context, error, onRetry: _submitReview);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        title: const Text('Write a review'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.productTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          const Text('Your rating', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final value = index + 1;
              return IconButton(
                onPressed: _submitting ? null : () => setState(() => _rating = value),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40),
                icon: Icon(
                  value <= _rating ? Icons.star : Icons.star_border,
                  color: const Color(0xFFFFA000),
                  size: 30,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reviewController,
            enabled: !_submitting,
            onChanged: (_) => setState(() => _error = null),
            minLines: 5,
            maxLines: 8,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: 'Share your feedback',
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Add photos', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_photos.length}/$_maxPhotos', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _photos.length; i++)
                _PhotoTile(
                  bytes: _photos[i].bytes,
                  onRemove: _submitting ? null : () => setState(() => _photos.removeAt(i)),
                ),
              if (_photos.length < _maxPhotos) _AddPhotoTile(onTap: _submitting ? null : _addPhotos),
            ],
          ),
          if (_photoError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_photoError!, style: const TextStyle(fontSize: 12, color: Colors.red)),
            ),
          const SizedBox(height: 22),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _reviewController.text.trim().isEmpty || _submitting
                  ? null
                  : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
              ),
              child: _submitting ? const ButtonSpinner() : const Text('Submit review'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedPhoto {
  final Uint8List bytes;
  final String filename;

  const _PickedPhoto(this.bytes, this.filename);
}

class _PhotoTile extends StatelessWidget {
  final Uint8List bytes;
  final VoidCallback? onRemove;

  const _PhotoTile({required this.bytes, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.close, size: 13, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: mainColor.withValues(alpha: .5)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: mainColor, size: 24),
            SizedBox(height: 4),
            Text('Add', style: TextStyle(fontSize: 11, color: mainColor)),
          ],
        ),
      ),
    );
  }
}
