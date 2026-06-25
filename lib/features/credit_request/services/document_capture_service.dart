import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class DocumentCaptureResult {
  const DocumentCaptureResult({
    required this.outputPath,
    required this.sizeKb,
    required this.sharpnessScore,
    required this.isSharpEnough,
  });

  final String outputPath;
  final int sizeKb;
  final double sharpnessScore;
  final bool isSharpEnough;
}

class DocumentCaptureService {
  DocumentCaptureService._();

  static const minSharpnessScore = 35.0;
  static const maxSizeKb = 800;
  static const maxWidth = 1600;

  static Future<DocumentCaptureResult?> processCameraFile(
    String sourcePath,
  ) async {
    final sourceBytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      return null;
    }

    final sharpnessScore = _normalizedSharpness(decoded);
    var working = decoded;
    if (working.width > maxWidth) {
      working = img.copyResize(working, width: maxWidth);
    }

    var quality = 85;
    late Uint8List output;
    do {
      output = Uint8List.fromList(img.encodeJpg(working, quality: quality));
      if (output.length <= maxSizeKb * 1024 || quality <= 45) {
        break;
      }
      quality -= 5;
    } while (quality > 45);

    final directory = File(sourcePath).parent.path;
    final outputPath = '$directory/doc_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(outputPath).writeAsBytes(output, flush: true);

    return DocumentCaptureResult(
      outputPath: outputPath,
      sizeKb: (output.length / 1024).ceil(),
      sharpnessScore: sharpnessScore,
      isSharpEnough: sharpnessScore >= minSharpnessScore,
    );
  }

  static double _normalizedSharpness(img.Image image) {
    final sample = image.width > 640
        ? img.copyResize(image, width: 640)
        : image;
    final gray = img.grayscale(sample);
    final variance = _laplacianVariance(gray);
    return (variance / 12).clamp(0, 100).toDouble();
  }

  static double _laplacianVariance(img.Image gray) {
    final width = gray.width;
    final height = gray.height;
    if (width < 3 || height < 3) {
      return 0;
    }

    final values = <double>[];
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final center = gray.getPixel(x, y).r.toInt();
        final laplacian = (-4 * center +
                gray.getPixel(x - 1, y).r.toInt() +
                gray.getPixel(x + 1, y).r.toInt() +
                gray.getPixel(x, y - 1).r.toInt() +
                gray.getPixel(x, y + 1).r.toInt())
            .toDouble();
        values.add(laplacian);
      }
    }

    if (values.isEmpty) {
      return 0;
    }

    final mean = values.reduce((a, b) => a + b) / values.length;
    var variance = 0.0;
    for (final value in values) {
      variance += pow(value - mean, 2);
    }
    return variance / values.length;
  }
}
