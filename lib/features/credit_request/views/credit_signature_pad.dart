import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class CreditSignaturePad extends StatefulWidget {
  const CreditSignaturePad({
    super.key,
    required this.onChanged,
    this.initialValue,
  });

  final ValueChanged<String?> onChanged;
  final String? initialValue;

  @override
  State<CreditSignaturePad> createState() => _CreditSignaturePadState();
}

class _CreditSignaturePadState extends State<CreditSignaturePad> {
  final List<Offset?> _points = [];
  bool _hasStroke = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _hasStroke = true;
                _points.add(details.localPosition);
              });
            },
            onPanEnd: (_) {
              _points.add(null);
              _exportSignature();
            },
            child: CustomPaint(
              painter: _SignaturePainter(_points),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _points.clear();
                  _hasStroke = false;
                });
                widget.onChanged(null);
              },
              child: const Text('Limpiar'),
            ),
            const Spacer(),
            Text(
              _hasStroke ? 'Firma capturada' : 'Firme dentro del recuadro',
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportSignature() async {
    if (!_hasStroke) {
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 320, 180),
      Paint()..color = Colors.white,
    );

    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    for (var index = 0; index < _points.length - 1; index++) {
      final current = _points[index];
      final next = _points[index + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(320, 180);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      return;
    }

    widget.onChanged(base64Encode(bytes.buffer.asUint8List()));
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
