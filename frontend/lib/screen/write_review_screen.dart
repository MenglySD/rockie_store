import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReviewSubmission {
  final int rating;
  final String description;
  final List<Uint8List> photos;

  const ReviewSubmission({
    required this.rating,
    required this.description,
    required this.photos,
  });
}

class WriteReviewScreen extends StatefulWidget {
  final String productName;
  final String productImage;

  const WriteReviewScreen({
    super.key,
    required this.productName,
    required this.productImage,
  });

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  static const _orange = Color(0xFFFF4D00);
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  final List<Uint8List> _photos = [];
  int _rating = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final remaining = 5 - _photos.length;
    if (remaining <= 0) return;

    final selected = await _picker.pickMultiImage(limit: remaining);
    if (selected.isEmpty || !mounted) return;

    final bytes = await Future.wait(selected.map((file) => file.readAsBytes()));
    if (!mounted) return;
    setState(() => _photos.addAll(bytes));
  }

  void _submit() {
    if (_rating == 0 || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a rating and write a short review.')),
      );
      return;
    }
    setState(() => _submitting = true);
    Navigator.of(context).pop(
      ReviewSubmission(
        rating: _rating,
        description: _descriptionController.text.trim(),
        photos: List.unmodifiable(_photos),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7FC),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
        ),
        title: const Text(
          'Write a Review',
          style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _panel(
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            widget.productImage,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 72,
                              height: 72,
                              child: ColoredBox(color: Color(0xFFF0ECEB), child: Icon(Icons.shopping_bag_outlined)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            widget.productName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your rating', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Row(
                          children: List.generate(
                            5,
                            (index) => IconButton(
                              onPressed: () => setState(() => _rating = index + 1),
                              padding: const EdgeInsets.only(right: 8),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 38,
                                color: _orange,
                              ),
                            ),
                          ),
                        ),
                        if (_rating > 0) ...[
                          const SizedBox(height: 8),
                          Text(_ratingLabel, style: const TextStyle(color: _orange, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _descriptionController,
                          minLines: 5,
                          maxLines: 7,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'What did you like or dislike? Share details to help other shoppers.',
                            hintStyle: const TextStyle(color: Color(0xFF98939A), fontSize: 14, height: 1.4),
                            filled: true,
                            fillColor: const Color(0xFFFAF9FB),
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECE7EA))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECE7EA))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _orange)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Add photos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text('Share up to 5 photos of your item.', style: TextStyle(fontSize: 12, color: Color(0xFF77737A))),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ...List.generate(_photos.length, (index) => _photoTile(index)),
                            if (_photos.length < 5)
                              InkWell(
                                onTap: _addPhotos,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF5F1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFFFD9CC)),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [Icon(Icons.add_a_photo_outlined, color: _orange), SizedBox(height: 5), Text('Add photo', style: TextStyle(fontSize: 11, color: _orange, fontWeight: FontWeight.w600))],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _ratingLabel => switch (_rating) {
        1 => 'Poor',
        2 => 'Fair',
        3 => 'Good',
        4 => 'Very good',
        _ => 'Excellent',
      };

  Widget _panel({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFF2E2E6)),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: child,
      );

  Widget _photoTile(int index) => SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_photos[index], width: 84, height: 84, fit: BoxFit.cover)),
            Positioned(
              top: -7,
              right: -7,
              child: IconButton.filled(
                onPressed: () => setState(() => _photos.removeAt(index)),
                style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF524A4A), padding: const EdgeInsets.all(4), minimumSize: const Size(28, 28)),
                icon: const Icon(Icons.close, size: 15),
              ),
            ),
          ],
        ),
      );
}
