import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../data/seller_providers.dart';

/// Khung ảnh nhỏ bo góc, có biểu tượng kính lúp, bấm vào để xem toàn màn hình.
class ThumbFrame extends StatelessWidget {
  const ThumbFrame({
    super.key,
    required this.child,
    required this.onTap,
    this.size = 96,
  });
  final Widget child;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.zoom_in, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ảnh minh chứng đã lưu trên Storage, hiện dạng ảnh nhỏ, bấm để xem lớn.
class ProofThumbnail extends ConsumerWidget {
  const ProofThumbnail({
    super.key,
    required this.bucket,
    required this.path,
    this.size = 96,
  });
  final String bucket;
  final String path;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(signedUrlProvider((bucket: bucket, path: path)));
    final Widget content = url.when(
      loading: () => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => const Center(child: Icon(Icons.broken_image_outlined)),
      data: (u) => Image.network(
        u,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
    return ThumbFrame(
      size: size,
      onTap: () => showProofDialog(context, bucket: bucket, path: path),
      child: content,
    );
  }
}

/// Màn hình xem ảnh toàn màn hình: chụm / lăn chuột để phóng to, kéo để di chuyển.
class ImageViewerPage extends StatelessWidget {
  const ImageViewerPage({super.key, required this.child, this.title});
  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(title ?? 'Xem ảnh'),
        ),
        body: Center(
          child: InteractiveViewer(minScale: 1, maxScale: 6, child: child),
        ),
      );
}

/// Xem ảnh vừa chọn từ máy (chưa upload).
void showMemoryImage(BuildContext context, Uint8List bytes, {String? title}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ImageViewerPage(title: title, child: Image.memory(bytes)),
    ),
  );
}

class _ProofViewer extends ConsumerWidget {
  const _ProofViewer({required this.bucket, required this.path});
  final String bucket;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(signedUrlProvider((bucket: bucket, path: path)));
    return ImageViewerPage(
      title: 'Ảnh minh chứng',
      child: url.when(
        loading: () => const CircularProgressIndicator(color: Colors.white),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Không tải được ảnh: ${errorText(e)}',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        data: (u) => Image.network(
          u,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
          errorBuilder: (context, error, stack) => const Text(
            'Không hiển thị được ảnh',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Xem ảnh minh chứng trong Storage toàn màn hình.
void showProofDialog(
  BuildContext context, {
  required String bucket,
  required String path,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _ProofViewer(bucket: bucket, path: path),
    ),
  );
}