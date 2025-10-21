import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repo = ProfileRepository();
  final _fullName = TextEditingController();
  final _employeeId = TextEditingController();
  String? _email;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _repo.ensureMyProfile();
      final p = await _repo.getMyProfile();
      _email = p['email'] as String?;
      _fullName.text = (p['full_name'] ?? '') as String;
      _employeeId.text = (p['employee_id'] ?? '') as String;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat profil: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repo.updateMyProfile(
        fullName: _fullName.text.trim(),
        employeeId: _employeeId.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil tersimpan')),
      );
      Navigator.of(context)
          .pop(true); // beri sinyal ke Home utk refresh jika perlu
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Supabase error: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal simpan: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _employeeId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Saya')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_email != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.email),
                    title: const Text('Email'),
                    subtitle: Text(_email!),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _fullName,
                  decoration: const InputDecoration(
                    labelText: 'Nama lengkap',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _employeeId,
                  decoration: const InputDecoration(
                    labelText: 'Employee ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Simpan'),
                ),
              ],
            ),
    );
  }
}
