import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class FaceRepository {
  final SupabaseClient _client = AppSupabase.client;

  Future<void> insertEmbedding({
    required String employeeId,
    required List<double> embedding,
    String model = 'mobilefacenet_112',
  }) async {
    final data = {
      'employee_id': employeeId,
      'embedding': embedding, // jsonb bisa terima List<double> langsung
      'dim': embedding.length,
      'model': model,
    };
    await _client.from('face_embeddings').insert(data);
  }

  Future<List<List<double>>> listEmbeddings(String employeeId) async {
    final rows = await _client
        .from('face_embeddings')
        .select('embedding')
        .eq('employee_id', employeeId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) =>
            (r['embedding'] as List).map((e) => (e as num).toDouble()).toList())
        .toList();
  }
}
