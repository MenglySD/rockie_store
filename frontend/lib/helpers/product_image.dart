import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Shows an API image URL (cached, with loading/error placeholders),
/// a data: URI, or a bundled asset path.
Widget productImage(
  String? path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  if (path == null || path.isEmpty) {
    return _ImagePlaceholder(width: width, height: height, error: true);
  }
  if (path.startsWith('data:image/')) {
    final commaIndex = path.indexOf(',');
    if (commaIndex >= 0) {
      return Image.memory(
        base64Decode(path.substring(commaIndex + 1)),
        fit: fit,
        width: width,
        height: height,
      );
    }
  }
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return _NetworkImage(url: path, fit: fit, width: width, height: height);
  }

  return Image.asset(
    path,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (_, _, _) =>
        _ImagePlaceholder(width: width, height: height, error: true),
  );
}

/// For CircleAvatar.backgroundImage and similar.
ImageProvider? networkImageProvider(String? url) =>
    url == null || url.isEmpty ? null : CachedNetworkImageProvider(url);

/// A cached network image that:
/// - decodes at the size it is shown (product photos are 1200×1600, about
///   8 MB each in memory at full size, but are shown ~180 px wide);
/// - retries a failed download twice before showing the error icon.
class _NetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  const _NetworkImage({
    required this.url,
    required this.fit,
    this.width,
    this.height,
  });

  @override
  State<_NetworkImage> createState() => _NetworkImageState();
}

class _NetworkImageState extends State<_NetworkImage> {
  static const _maxRetries = 2;

  int _attempt = 0;
  bool _retryScheduled = false;

  void _retryLater() {
    if (_attempt >= _maxRetries || _retryScheduled) return;
    _retryScheduled = true;
    // The saved copy may be damaged (e.g. a broken download): remove it so
    // the retry downloads the image again instead of re-reading the same file.
    CachedNetworkImage.evictFromCache(widget.url);
    Future.delayed(Duration(seconds: 1 + _attempt), () {
      if (!mounted) return;
      setState(() {
        _attempt++;
        _retryScheduled = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.width;
    final height = widget.height;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decode at the larger side of the box (photos are portrait or
        // square), in physical pixels; full size when the box is unbounded.
        double? side(double? fixed, double max) =>
            fixed != null && fixed.isFinite
            ? fixed
            : (max.isFinite ? max : null);
        final w = side(width, constraints.maxWidth);
        final h = side(height, constraints.maxHeight);
        final largest = [
          w,
          h,
        ].whereType<double>().fold<double>(0, (a, b) => a > b ? a : b);
        final cacheWidth = largest > 0
            ? (largest * MediaQuery.devicePixelRatioOf(context)).round()
            : null;

        return CachedNetworkImage(
          key: ValueKey(_attempt),
          imageUrl: widget.url,
          fit: widget.fit,
          width: width,
          height: height,
          memCacheWidth: cacheWidth,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, _) =>
              _ImagePlaceholder(width: width, height: height),
          errorWidget: (_, _, _) {
            _retryLater();
            // Keep showing the spinner while a retry is coming.
            return _ImagePlaceholder(
              width: width,
              height: height,
              error: _attempt >= _maxRetries,
            );
          },
        );
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final bool error;

  const _ImagePlaceholder({this.width, this.height, this.error = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF3F2F0),
      alignment: Alignment.center,
      child: error
          ? const Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey,
              size: 28,
            )
          : const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFCCCCCC),
              ),
            ),
    );
  }
}
