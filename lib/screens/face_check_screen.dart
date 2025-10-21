import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../repositories/face_repository.dart';
import '../services/face_embedder.dart';

class FaceCheckScreen extends StatefulWidget {
  final String employeeId;
  final bool returnEmbedding; // true = verify mode (pop embedding)

  const FaceCheckScreen({
    super.key,
    required this.employeeId,
    this.returnEmbedding = false,
  });

  @override
  State<FaceCheckScreen> createState() => _FaceCheckScreenState();
}

class _FaceCheckScreenState extends State<FaceCheckScreen> {
  CameraController? _controller;
  late final FaceDetector _detector;
  FaceEmbedder? _embedder;
  final _faceRepo = FaceRepository();

  bool _initializing = true;
  bool _busy = false;
  bool _hasPermission = false;

  List<Face> _faces = [];
  Size? _rawImageSize; // ukuran frame kamera mentah (untuk scale overlay)
  int _sensorRotation = 0;

  // ====== Liveness (kedip) ======
  bool _livenessPassed = false;
  int _blinkCount = 0;
  final int _targetBlinks = 1; // butuh 1x kedip
  bool? _prevEyesOpen; // null saat awal
  final double _eyeOpenThr = 0.7; // ambang mata terbuka
  final double _eyeClosedThr = 0.3; // ambang mata tertutup
  final double _minFaceAreaRatio = 0.12; // 12% dari frame kamera
  // ==============================

  bool _isFaceBigEnough(Face f) {
    if (_rawImageSize == null) return false;
    final area = f.boundingBox.width * f.boundingBox.height;
    final total = _rawImageSize!.width * _rawImageSize!.height;
    return (area / total) >= _minFaceAreaRatio;
  }

  bool get _isFront =>
      _controller?.description.lensDirection == CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: true,
        enableContours: true,
        minFaceSize: 0.10, // turunkan dari 0.15 -> 0.10
      ),
    );
    _bootstrap();
    _loadEmbedder();
  }

  Future<void> _loadEmbedder() async {
    try {
      _embedder = await FaceEmbedder
          .load(); // ganti embeddingLength jika modelmu 128-dim
      debugPrint('Face model loaded');
    } catch (e) {
      debugPrint('Load model error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal muat model: $e')),
      );
    }
  }

  Future<void> _bootstrap() async {
    final status = await Permission.camera.request();
    _hasPermission = status.isGranted;
    if (!_hasPermission) {
      if (mounted) {
        setState(() => _initializing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin kamera ditolak')),
        );
      }
      return;
    }
    await _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      _sensorRotation = front.sensorOrientation;

      _controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _controller!.initialize();

      // ukuran frame mentah (note: w/h tertukar pada preview)
      _rawImageSize = Size(
        _controller!.value.previewSize!.height,
        _controller!.value.previewSize!.width,
      );

      // mulai stream
      await _controller!.startImageStream(_onImage);
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal inisialisasi kamera: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // Saat hot reload, hentikan stream & reinit kamera supaya tidak crash/putus koneksi.
    _restartCameraForHotReload();
  }

  Future<void> _restartCameraForHotReload() async {
    try {
      // Wajib 1 wajah
      if (_faces.length != 1) {
        throw Exception('Harus tepat 1 wajah pada frame');
      }
// Wajah harus cukup besar (dekatkan ke kamera)
      final f = _faces.first;
      if (!_isFaceBigEnough(f)) {
        throw Exception('Wajah terlalu kecil. Dekatkan wajah ke kamera.');
      }
      await _controller?.stopImageStream();
    } catch (_) {}
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;

    if (!mounted) return;
    setState(() {
      _initializing = true;
      _faces = [];
      // reset liveness agar status konsisten setelah reload
      _livenessPassed = false;
      _blinkCount = 0;
      _prevEyesOpen = null;
    });

    await _initCamera();
  }

  Future<void> _onImage(CameraImage image) async {
    if (_busy) return;
    _busy = true;
    try {
      final faces = await _detectFaces(image);
      if (!mounted) return;
      setState(() => _faces = faces);

      // Update liveness (hanya pada mode verifikasi)
      if (widget.returnEmbedding && faces.isNotEmpty && !_livenessPassed) {
        _updateLivenessByBlink(faces.first);
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('processImage error: $e');
    } finally {
      _busy = false;
    }
  }

  Future<List<Face>> _detectFaces(CameraImage image) async {
    final bytes = image.planes.fold<List<int>>(
      <int>[],
      (list, p) => list..addAll(p.bytes),
    );

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotationValue.fromRawValue(_sensorRotation) ??
          InputImageRotation.rotation0deg,
      format: InputImageFormat.nv21, // <-- NV21
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    final input = InputImage.fromBytes(
      bytes: Uint8List.fromList(bytes),
      metadata: metadata,
    );

    return _detector.processImage(input);
  }

  void _updateLivenessByBlink(Face f) {
    final le = f.leftEyeOpenProbability;
    final re = f.rightEyeOpenProbability;
    if (le == null || re == null) return;

    final bothOpen = (le >= _eyeOpenThr) && (re >= _eyeOpenThr);
    final bothClosed = (le <= _eyeClosedThr) && (re <= _eyeClosedThr);

    if (_prevEyesOpen == null) {
      _prevEyesOpen = bothOpen;
      return;
    }
    if (_prevEyesOpen == true && bothClosed) {
      _prevEyesOpen = false;
      return;
    }
    if (_prevEyesOpen == false && bothOpen) {
      _prevEyesOpen = true;
      _blinkCount += 1;
      if (_blinkCount >= _targetBlinks) _livenessPassed = true;
    }
  }

  Future<List<double>> _captureEmbedding() async {
    _embedder ??= await FaceEmbedder.load();
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Kamera belum siap');
    }
    if (_faces.isEmpty) throw Exception('Wajah belum terdeteksi');
    if (_embedder == null) throw Exception('Model belum siap');

    await _controller!.stopImageStream();
    final pic = await _controller!.takePicture();
    final bytes = await pic.readAsBytes();

    final emb = await _embedder!.embedFromJpegBytes(
      jpegBytes: bytes,
      faceBoxOnPreview: _faces.first.boundingBox,
      previewSize: _rawImageSize!,
      mirror: _isFront,
      rotateDegrees: _sensorRotation,
    );

    try {
      await _controller?.startImageStream(_onImage);
    } catch (_) {}
    return emb;
  }

  Future<void> _verifyAndReturn() async {
    try {
      final emb = await _captureEmbedding();
      if (!mounted) return;
      Navigator.of(context).pop(emb); // kirim embedding ke HomeScreen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal verifikasi: $e')),
      );
    }
  }

  Future<void> _saveMyFace() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_faces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wajah belum terdeteksi')),
      );
      return;
    }
    if (_embedder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model belum siap')),
      );
      return;
    }

    const samples = 3; // jumlah sampel yang akan disimpan
    try {
      for (var i = 0; i < samples; i++) {
        if (!mounted) return;

        // beri info progres
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Mengambil sampel wajah ${i + 1}/$samples...')),
        );

        // pastikan masih ada wajah di frame (tunggu sebentar kalau hilang)
        var attempts = 0;
        while (_faces.isEmpty && attempts < 40) {
          await Future.delayed(
              const Duration(milliseconds: 50)); // ~2 detik total
          attempts++;
        }
        if (_faces.isEmpty) {
          throw Exception('Wajah hilang saat pengambilan. Coba lagi.');
        }

        // ambil embedding 1x dan simpan ke Supabase
        final emb = await _captureEmbedding();
        await _faceRepo.insertEmbedding(
          employeeId: widget.employeeId,
          embedding: emb,
          model: 'mobilefacenet_112',
        );

        // jeda ringan antar sampel
        await Future.delayed(const Duration(milliseconds: 350));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tersimpan 3 sampel wajah ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal simpan wajah: $e')),
      );
    } finally {
      // pastikan stream balik lagi kalau sempat berhenti
      try {
        await _controller?.startImageStream(_onImage);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _detector.close();
    _embedder?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _hasPermission &&
        !_initializing &&
        _controller != null &&
        _controller!.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('jah'),
        backgroundColor: Colors.black,
      ),
      body: !ready
          ? Center(
              child: _initializing
                  ? const CircularProgressIndicator()
                  : const Text(
                      'Kamera belum siap / izin ditolak',
                      style: TextStyle(color: Colors.white),
                    ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                if (_rawImageSize != null)
                  CustomPaint(
                    painter: _FaceOverlayPainter(
                      faces: _faces,
                      imageSize: _rawImageSize!,
                      mirror: _isFront,
                    ),
                  ),
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: _StatusChip(hasFace: _faces.isNotEmpty),
                ),
                if (widget.returnEmbedding)
                  Positioned(
                    top: 54, // di bawah chip Face: OK
                    left: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: (_livenessPassed ? Colors.green : Colors.orange)
                            .withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _livenessPassed
                            ? 'Liveness: OK (kedip terdeteksi)'
                            : 'Liveness: Kedipkan mata sekali',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: (ready &&
              _faces.length == 1 &&
              _isFaceBigEnough(_faces.first))
          ? FloatingActionButton.extended(
              onPressed: (widget.returnEmbedding && !_livenessPassed)
                  ? null // menunggu kedip (liveness)
                  : (widget.returnEmbedding ? _verifyAndReturn : _saveMyFace),
              icon: Icon(
                  widget.returnEmbedding ? Icons.verified_user : Icons.save),
              label: Text(widget.returnEmbedding
                  ? 'Verifikasi Sekarang'
                  : 'Simpan Wajah Saya'),
            )
          : null,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool hasFace;
  const _StatusChip({required this.hasFace});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasFace
            ? Colors.green.withOpacity(0.9)
            : Colors.red.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        hasFace ? 'Face: OK' : 'Face: Tidak Terdeteksi',
        textAlign: TextAlign.center,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FaceOverlayPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize; // ukuran frame mentah
  final bool mirror; // kamera depan perlu mirror

  _FaceOverlayPainter({
    required this.faces,
    required this.imageSize,
    required this.mirror,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    for (final f in faces) {
      Rect r = f.boundingBox;

      Rect box = Rect.fromLTRB(
        r.left * scaleX,
        r.top * scaleY,
        r.right * scaleX,
        r.bottom * scaleY,
      );

      if (mirror) {
        final left = size.width - box.right;
        final right = size.width - box.left;
        box = Rect.fromLTRB(left, box.top, right, box.bottom);
      }

      paint.color =
          faces.length == 1 ? Colors.greenAccent : Colors.orangeAccent;
      canvas.drawRect(box, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FaceOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces || oldDelegate.imageSize != imageSize;
  }
}
