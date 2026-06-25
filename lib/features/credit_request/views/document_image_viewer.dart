import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/theme/app_colors.dart';

class DocumentImageViewer extends StatelessWidget {
  const DocumentImageViewer({
    super.key,
    required this.title,
    required this.imagePath,
    this.onRetake,
    this.onDelete,
  });

  final String title;
  final String imagePath;
  final VoidCallback? onRetake;
  final VoidCallback? onDelete;

  static Future<void> open(
    BuildContext context, {
    required String title,
    required String imagePath,
    VoidCallback? onRetake,
    VoidCallback? onDelete,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentImageViewer(
          title: title,
          imagePath: imagePath,
          onRetake: onRetake,
          onDelete: onDelete,
        ),
      ),
    );
  }

  ImageProvider<Object> get _imageProvider {
    if (imagePath.startsWith('http')) {
      return NetworkImage(imagePath);
    }
    if (imagePath.startsWith('data:')) {
      final encoded = imagePath.split(',').last;
      return MemoryImage(base64Decode(encoded));
    }
    return FileImage(File(imagePath));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
        actions: [
          if (onRetake != null)
            IconButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetake!();
              },
              icon: const Icon(Icons.camera_alt_outlined),
              tooltip: 'Retomar',
            ),
          if (onDelete != null)
            IconButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Eliminar documento'),
                    content: const Text(
                      'Desea eliminar esta foto del expediente?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  Navigator.of(context).pop();
                  onDelete!();
                }
              },
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
            ),
        ],
      ),
      body: PhotoView(
        imageProvider: _imageProvider,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, __) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
    );
  }
}
