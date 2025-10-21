import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class FaceEmbedder {
  final Interpreter _interpreter;
  final int inputSize;
  final int embeddingLength;

  FaceEmbedder._(this._interpreter,
      {required this.inputSize, required this.embeddingLength});

  static Future<FaceEmbedder> load({
    String assetPath = 'assets/models/mobilefacenet.tflite',
    int inputSize = 112,
    int embeddingLength = 192,
    int threads = 2,
  }) async {
    final options = InterpreterOptions()..threads = threads;

    // Coba cara standar
    try {
      final i1 = await Interpreter.fromAsset(assetPath, options: options);
      debugPrint('Face model loaded via fromAsset("$assetPath")');
      return FaceEmbedder._(i1,
          inputSize: inputSize, embeddingLength: embeddingLength);
    } catch (e1) {
      // Fallback + LOG ukuran file asset
      try {
        final bd = await rootBundle.load(assetPath);
        final len = bd.lengthInBytes;
        debugPrint('Face model bytes length: $len');
        final buf = bd.buffer.asUint8List();
        if (len == 0 || buf.isEmpty) {
          throw Exception(
              'File model 0 bytes — asset tidak terbawa atau file korup.');
        }
        final i2 = await Interpreter.fromBuffer(buf, options: options);
        debugPrint('Face model loaded via fromBuffer("$assetPath")');
        return FaceEmbedder._(i2,
            inputSize: inputSize, embeddingLength: embeddingLength);
      } catch (e2) {
        throw Exception(
            'Gagal load model "$assetPath".\n- fromAsset: $e1\n- fromBuffer: $e2');
      }
    }
  }

  void dispose() => _interpreter.close();

  List<double> embedImage(img.Image rgb) {
    final resized = img.copyResize(
      rgb,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Tensor input [1, H, W, 3] dengan normalisasi [-1, 1]
    final input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final px = resized.getPixel(x, y)
                as img.Pixel; // <- v4 mengembalikan Pixel
            final r = px.r.toDouble();
            final g = px.g.toDouble();
            final b = px.b.toDouble();
            return [
              (r - 127.5) / 128.0,
              (g - 127.5) / 128.0,
              (b - 127.5) / 128.0,
            ];
          },
        ),
      ),
    );

    final output = List.generate(1, (_) => List.filled(embeddingLength, 0.0));
    _interpreter.run(input, output);

    final emb = List<double>.from(output[0]);

    if (emb.length != embeddingLength) {
      throw Exception(
          'Model-output mismatch: expected $embeddingLength, got ${emb.length}. '
          'Ubah embeddingLength atau ganti model.');
    }
    return _l2normalize(emb);
  }

  Future<List<double>> embedFromJpegBytes({
    required Uint8List jpegBytes,
    required Rect faceBoxOnPreview,
    required Size previewSize,
    required bool mirror,
    double boxScale = 1.4,
    int rotateDegrees = 0,
  }) async {
    final decoded = img.decodeImage(jpegBytes);
    if (decoded == null) {
      throw Exception('Gagal decode JPEG');
    }

    img.Image rgb = decoded;

// ⬇️ putar gambar sesuai orientasi sensor (0/90/180/270)
    if (rotateDegrees % 360 != 0) {
      // package:image menerima derajat (positif = searah jarum jam)
      rgb = img.copyRotate(rgb, angle: rotateDegrees);
    }

    // skala bbox dari koordinat preview → ke koordinat foto actual
    final scaleX = rgb.width / previewSize.width;
    final scaleY = rgb.height / previewSize.height;

    var mapped = Rect.fromLTRB(
      faceBoxOnPreview.left * scaleX,
      faceBoxOnPreview.top * scaleY,
      faceBoxOnPreview.right * scaleX,
      faceBoxOnPreview.bottom * scaleY,
    );

    // mirror horizontal bila kamera depan
    if (mirror) {
      mapped = Rect.fromLTRB(
        rgb.width - mapped.right,
        mapped.top,
        rgb.width - mapped.left,
        mapped.bottom,
      );
    }

    // buat kotak persegi + margin
    final cx = (mapped.left + mapped.right) / 2.0;
    final cy = (mapped.top + mapped.bottom) / 2.0;
    final side = max(mapped.width, mapped.height) * boxScale;

    double left = cx - side / 2;
    double top = cy - side / 2;
    double right = cx + side / 2;
    double bottom = cy + side / 2;

    // clamp ke batas gambar
    left = left.clamp(0.0, rgb.width - 1.0);
    top = top.clamp(0.0, rgb.height - 1.0);
    right = right.clamp(1.0, rgb.width.toDouble());
    bottom = bottom.clamp(1.0, rgb.height.toDouble());

    final crop = img.copyCrop(
      rgb,
      x: left.round(),
      y: top.round(),
      width: (right - left).round(),
      height: (bottom - top).round(),
    );

    return embedImage(crop);
  }

  static List<double> _l2normalize(List<double> v) {
    final s = v.fold<double>(0.0, (sum, x) => sum + x * x);
    final n = sqrt(s);
    if (n == 0) return v;
    return v.map((x) => x / n).toList();
  }

  /// cosine similarity: 1.0 = identik, 0 = ortogonal
  static double cosineSim(List<double> a, List<double> b) {
    assert(a.length == b.length);
    double dot = 0, na = 0, nb = 0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    return dot / (sqrt(na) * sqrt(nb)).clamp(1e-8, double.infinity);
  }
}
