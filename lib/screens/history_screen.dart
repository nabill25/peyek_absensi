import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/attendance_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final repo = AttendanceRepository();
  List<Map<String, dynamic>> _itemsAll = [];
  bool loading = true;
  bool hideMock = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final rows = await repo.fetchRecentAttendance(limit: 100);
      setState(() => _itemsAll = rows);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal memuat riwayat: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get _items {
    if (!hideMock) return _itemsAll;
    return _itemsAll.where((m) => (m['is_mock'] as bool?) != true).toList();
  }

  String _fmtTs(dynamic tsValue) {
    try {
      final dt = DateTime.parse(tsValue.toString()).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return tsValue.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Absensi')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  // Toggle sembunyikan MOCK
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: SwitchListTile.adaptive(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sembunyikan presensi MOCK'),
                      value: hideMock,
                      onChanged: (v) => setState(() => hideMock = v),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final m = _items[i];
                        final kind = (m['kind'] ?? '').toString();
                        final ts = _fmtTs(m['ts']);
                        final acc =
                            (m['accuracy_m'] as num?)?.toStringAsFixed(0) ??
                                '-';
                        final dist =
                            (m['distance_m'] as num?)?.toStringAsFixed(1) ??
                                '-';
                        final lat =
                            (m['lat'] as num?)?.toStringAsFixed(6) ?? '-';
                        final lng =
                            (m['lng'] as num?)?.toStringAsFixed(6) ?? '-';
                        final isMock = (m['is_mock'] as bool?) ?? false;

                        final icon = kind == 'IN'
                            ? const Icon(Icons.login, color: Colors.green)
                            : const Icon(Icons.logout, color: Colors.red);

                        return ListTile(
                          leading: icon,
                          title: Text('$kind — $ts'),
                          subtitle: Text(
                              'Jarak $dist m • Akurasi $acc m\n($lat, $lng)'),
                          isThreeLine: true,
                          trailing: isMock
                              ? Chip(
                                  label: const Text('MOCK'),
                                  backgroundColor: Colors.red.withOpacity(0.15),
                                  side: BorderSide(
                                      color: Colors.red.withOpacity(0.4)),
                                )
                              : null,
                          tileColor:
                              isMock ? Colors.red.withOpacity(0.03) : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
