import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart';
import '../repositories/profile_repository.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/face_repository.dart';
import '../services/face_embedder.dart';
import '../services/location_service.dart';
import '../widgets/map_view.dart';
import 'history_screen.dart';
import 'payroll_screen.dart';
import 'face_check_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Repo profil dipakai untuk memastikan/ambil employee_id
final _profileRepo = ProfileRepository();

class _HomeScreenState extends State<HomeScreen> {
  final _attendanceRepo = AttendanceRepository();
  final _faceRepo = FaceRepository();
  final double faceThreshold = 0.55; // 0.5–0.7 sesuai uji

  String storeName = 'Memuat...';
  LatLng? center; // titik pusat geofence
  double radiusM = 40; // meter
  double accThresh = 20; // meter
  LatLng? current; // posisi user terakhir
  bool busy = false;

  /// Diambil dari tabel `profiles` (BUKAN hardcoded)
  String? employeeId;

  @override
  void initState() {
    super.initState();
    _ensureProfile();
    _loadSettings();
    _loadEmployeeId(); // ambil employee_id milik user
  }

  Future<void> _loadEmployeeId() async {
    try {
      await _profileRepo.ensureMyProfile(); // pastikan baris profil ada
      final id = await _profileRepo.getMyEmployeeId();

      if (!mounted) return;
      setState(() => employeeId = id);

      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profil belum memiliki employee_id. Minta admin cek RLS/policy tabel profiles.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal sinkronisasi profil: $e')),
      );
    }
  }

  Future<void> _loadSettings() async {
    try {
      final s = await _attendanceRepo.loadSettings();
      if (!mounted) return;

      if (s == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings kosong di Supabase')),
        );
        return;
      }

      setState(() {
        storeName = (s['store_name'] as String?) ?? 'Toko';
        center = LatLng(s['center_lat'] as double, s['center_lng'] as double);
        radiusM = s['radius_m'] as double;
        accThresh = s['accuracy_threshold_m'] as double;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat settings: $e')),
      );
    }
  }

  Future<void> _doAttendance(String kind) async {
    if (employeeId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('employee_id belum tersedia. Hubungi admin.'),
          ),
        );
      }
      return;
    }
    if (center == null) return;

    setState(() => busy = true);
    try {
      final ok = await LocationService.ensurePermission();
      if (!mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Aktifkan layanan lokasi & izinkan akses')),
        );
        return;
      }

      final pos = await LocationService.current();
      if (!mounted) return;

      final dist = LocationService.distanceMeters(
        lat1: center!.latitude,
        lng1: center!.longitude,
        lat2: pos.latitude,
        lng2: pos.longitude,
      );

      if (pos.accuracy > accThresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Akurasi buruk (${pos.accuracy.toStringAsFixed(0)} m). Coba lagi.')),
        );
        return;
      }
      if (dist > radiusM) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Di luar area kerja (${dist.toStringAsFixed(1)} m)')),
        );
        return;
      }

      final mocked = LocationService.isMocked(pos);

      final faceOK = await _verifyFace();
      if (!mounted) return;
      if (!faceOK) return;

      await _attendanceRepo.insertAttendance(
        employeeId: employeeId!,
        kind: kind,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy,
        distanceM: dist,
        isMock: mocked,
      );

      if (!mounted) return;
      setState(() => current = LatLng(pos.latitude, pos.longitude));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mocked
                ? 'Lokasi terdeteksi MOCK — dicatat untuk audit, tidak dianggap sah.'
                : 'Absen $kind berhasil (jarak ${dist.toStringAsFixed(1)} m)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal absen: $e')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _ensureProfile() async {
    try {
      await _profileRepo.ensureMyProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal inisialisasi profil: $e')),
      );
    }
  }

  Future<bool> _verifyFace() async {
    if (employeeId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('employee_id belum tersedia. Hubungi admin.')),
        );
      }
      return false;
    }

    final stored = await _faceRepo.listEmbeddings(employeeId!);
    if (!mounted) return false;

    if (stored.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Belum ada wajah tersimpan. Daftarkan dulu.')),
      );
      return false;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FaceCheckScreen(
          employeeId: employeeId!,
          returnEmbedding: true, // mode verifikasi
        ),
      ),
    );

    if (!mounted) return false;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifikasi dibatalkan')),
      );
      return false;
    }

    final List<double> probe =
        (result as List).map((e) => (e as num).toDouble()).toList();

    double best = -1.0;
    for (final ref in stored) {
      final sim = FaceEmbedder.cosineSim(ref, probe);
      if (sim > best) best = sim;
    }

    if (best >= faceThreshold) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Verifikasi wajah OK (sim=${best.toStringAsFixed(2)})')),
      );
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Verifikasi wajah gagal (sim=${best.toStringAsFixed(2)})')),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ====== BODY (peta + tombol) ======
    final Widget body = (center == null)
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.face_retouching_natural),
                    label: const Text('Buka Deteksi Wajah (Beta)'),
                    onPressed: (employeeId == null)
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FaceCheckScreen(
                                  employeeId: employeeId!,
                                ),
                              ),
                            );
                          },
                  ),
                ),
              ),
              Expanded(
                child: MapView(
                  center: center!,
                  radiusM: radiusM,
                  current: current,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : () => _doAttendance('IN'),
                        icon: const Icon(Icons.login),
                        label: const Text('Absen Masuk'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : () => _doAttendance('OUT'),
                        icon: const Icon(Icons.logout),
                        label: const Text('Absen Pulang'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

    // ====== SCAFFOLD ======
    return Scaffold(
      appBar: AppBar(
        title: Text(storeName),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat Absensi',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calculate),
            tooltip: 'Hitung Payroll',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PayrollScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.face_retouching_natural),
            tooltip: 'Deteksi Wajah (Beta)',
            onPressed: (employeeId == null)
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            FaceCheckScreen(employeeId: employeeId!),
                      ),
                    );
                  },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profil',
            onPressed: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
              if (changed == true) {
                if (!mounted) return;
                final id = await ProfileRepository().getMyEmployeeId();
                if (mounted) setState(() => employeeId = id);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Anda telah keluar')),
              );
              // AuthGate akan otomatis kembali ke layar login
            },
          ),
        ],
      ),
      body: body, // <<< PENTING: tampilkan konten utama
    );
  }
}
