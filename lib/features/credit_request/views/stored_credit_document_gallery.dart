import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/web_theme.dart';
import '../models/pipeline_models.dart';
import 'credit_detail_colors.dart';

/// Resuelve la fuente de imagen de un documento almacenado.
ImageProvider<Object>? creditDocumentImageProvider(String url) {
  if (url.isEmpty) {
    return null;
  }
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return NetworkImage(url);
  }
  if (url.startsWith('data:')) {
    try {
      final encoded = url.split(',').last;
      return MemoryImage(base64Decode(encoded));
    } catch (_) {
      return null;
    }
  }
  if (!kIsWeb && url.startsWith('/')) {
    return FileImage(File(url));
  }
  if (!kIsWeb) {
    return FileImage(File(url));
  }
  return null;
}

/// Miniatura de documento con soporte data-uri, http(s) y archivo local.
class CreditDocumentThumbnail extends StatelessWidget {
  const CreditDocumentThumbnail({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.iconSize = 32,
  });

  final String url;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final provider = creditDocumentImageProvider(url);
    if (provider == null) {
      return _placeholder();
    }

    return Image(
      image: provider,
      fit: fit,
      errorBuilder: (_, __, ___) => _placeholder(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return Center(
          child: CircularProgressIndicator(
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded /
                    progress.expectedTotalBytes!
                : null,
            strokeWidth: 2,
            color: CreditDetailColors.accent,
          ),
        );
      },
    );
  }

  Widget _placeholder() {
    return Container(
      color: CreditDetailColors.cardBgHighest,
      child: Center(
        child: Icon(
          Icons.description_outlined,
          size: iconSize,
          color: CreditDetailColors.textSecondary,
        ),
      ),
    );
  }
}

/// Galería ampliada con zoom, navegación y layout optimizado para web.
class StoredCreditDocumentGallery extends StatefulWidget {
  const StoredCreditDocumentGallery({
    super.key,
    required this.documents,
    required this.initialIndex,
  });

  final List<StoredCreditDocument> documents;
  final int initialIndex;

  static Future<void> open(
    BuildContext context, {
    required List<StoredCreditDocument> documents,
    int initialIndex = 0,
  }) {
    if (documents.isEmpty) {
      return Future.value();
    }

    final index = initialIndex.clamp(0, documents.length - 1);

    if (kIsWeb) {
      return showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        builder: (context) => StoredCreditDocumentGallery(
          documents: documents,
          initialIndex: index,
        ),
      );
    }

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => StoredCreditDocumentGallery(
          documents: documents,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  State<StoredCreditDocumentGallery> createState() =>
      _StoredCreditDocumentGalleryState();
}

class _StoredCreditDocumentGalleryState extends State<StoredCreditDocumentGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  StoredCreditDocument get _current => widget.documents[_currentIndex];

  void _goTo(int index) {
    if (index < 0 || index >= widget.documents.length) {
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openExternal() async {
    final url = _current.storageUrl;
    if (!url.startsWith('http')) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 820),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: _buildContent(compactMeta: false),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _buildContent(compactMeta: true)),
    );
  }

  Widget _buildContent({required bool compactMeta}) {
    final document = _current;
    final hasMultiple = widget.documents.length > 1;
    final isWeb = kIsWeb;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GalleryToolbar(
          title: document.typeLabel,
          subtitle: hasMultiple
              ? '${_currentIndex + 1} de ${widget.documents.length}'
              : '${document.sizeKb} KB',
          isWeb: isWeb,
          canOpenExternal: document.storageUrl.startsWith('http'),
          onClose: _close,
          onOpenExternal: _openExternal,
        ),
        Expanded(
          child: isWeb && !compactMeta
              ? Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildViewer(hasMultiple)),
                          SizedBox(
                            width: 280,
                            child: _DocumentMetaPanel(document: document),
                          ),
                        ],
                      ),
                    ),
                    if (hasMultiple) _ThumbnailStrip(
                      documents: widget.documents,
                      currentIndex: _currentIndex,
                      onSelected: _goTo,
                    ),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: _buildViewer(hasMultiple)),
                    if (!isWeb)
                      _DocumentMetaPanel(
                        document: document,
                        compact: true,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildViewer(bool hasMultiple) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ColoredBox(
          color: kIsWeb ? const Color(0xFF0D1C2D) : Colors.black,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.documents.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return _ZoomableDocumentPage(
                document: widget.documents[index],
              );
            },
          ),
        ),
        if (hasMultiple) ...[
          Positioned(
            left: 8,
            child: _NavButton(
              icon: Icons.chevron_left,
              enabled: _currentIndex > 0,
              onPressed: () => _goTo(_currentIndex - 1),
            ),
          ),
          Positioned(
            right: 8,
            child: _NavButton(
              icon: Icons.chevron_right,
              enabled: _currentIndex < widget.documents.length - 1,
              onPressed: () => _goTo(_currentIndex + 1),
            ),
          ),
        ],
      ],
    );
  }
}

class _GalleryToolbar extends StatelessWidget {
  const _GalleryToolbar({
    required this.title,
    required this.subtitle,
    required this.isWeb,
    required this.canOpenExternal,
    required this.onClose,
    required this.onOpenExternal,
  });

  final String title;
  final String subtitle;
  final bool isWeb;
  final bool canOpenExternal;
  final VoidCallback onClose;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isWeb ? Colors.white : Colors.black,
        border: Border(
          bottom: BorderSide(
            color: isWeb
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white24,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: isWeb ? WebTheme.textPrimary : Colors.white),
            tooltip: 'Cerrar',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isWeb ? WebTheme.textPrimary : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isWeb ? WebTheme.textSecondary : Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (canOpenExternal)
            IconButton(
              onPressed: onOpenExternal,
              icon: Icon(
                Icons.open_in_new,
                color: isWeb ? WebTheme.brandCyanDark : Colors.white,
              ),
              tooltip: 'Abrir en pestaña nueva',
            ),
        ],
      ),
    );
  }
}

class _DocumentMetaPanel extends StatelessWidget {
  const _DocumentMetaPanel({
    required this.document,
    this.compact = false,
  });

  final StoredCreditDocument document;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      ('Tipo', document.typeLabel),
      ('Codigo', document.typeCode),
      ('Tamaño', '${document.sizeKb} KB'),
      if (document.sharpnessScore != null)
        ('Nitidez', document.sharpnessScore!.toStringAsFixed(0)),
      ('Registrado', _formatDate(document.createdAt)),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: compact ? Colors.black : WebTheme.pageBackground,
        border: compact
            ? null
            : const Border(
                left: BorderSide(color: Color(0x14000000)),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(
            'Detalle del documento',
            style: TextStyle(
              color: compact ? Colors.white : WebTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          for (final (label, value) in items) ...[
            _MetaRow(
              label: label,
              value: value,
              light: !compact,
            ),
            const SizedBox(height: 8),
          ],
          if (!compact) ...[
            const Spacer(),
            const Text(
              'Usa la rueda del mouse o pellizco para hacer zoom.',
              style: TextStyle(
                color: WebTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    required this.light,
  });

  final String label;
  final String value;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              color: light ? WebTheme.textSecondary : Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: light ? WebTheme.textPrimary : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoomableDocumentPage extends StatelessWidget {
  const _ZoomableDocumentPage({required this.document});

  final StoredCreditDocument document;

  @override
  Widget build(BuildContext context) {
    final provider = creditDocumentImageProvider(document.storageUrl);

    if (provider == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'Vista previa no disponible',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
      );
    }

    return PhotoView(
      imageProvider: provider,
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      backgroundDecoration: BoxDecoration(
        color: kIsWeb ? const Color(0xFF0D1C2D) : Colors.black,
      ),
      loadingBuilder: (_, __) => const Center(
        child: CircularProgressIndicator(color: WebTheme.brandCyan),
      ),
      errorBuilder: (_, __, ___) => Center(
        child: Text(
          'No se pudo cargar la imagen',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
      ),
    );
  }
}

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({
    required this.documents,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<StoredCreditDocument> documents;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x14000000))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: documents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == currentIndex;
          return InkWell(
            onTap: () => onSelected(index),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? WebTheme.brandCyanDark
                      : Colors.black.withValues(alpha: 0.08),
                  width: selected ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: CreditDocumentThumbnail(
                url: documents[index].storageUrl,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: enabled ? Colors.white : Colors.white38,
            size: 28,
          ),
        ),
      ),
    );
  }
}
