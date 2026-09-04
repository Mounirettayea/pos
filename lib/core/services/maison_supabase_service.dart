import 'package:supabase_flutter/supabase_flutter.dart';

class MaisonSupabaseService {
  MaisonSupabaseService._();

  static final instance = MaisonSupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    final response = await client
        .from('mat_products')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> product,
  ) async {
    final response =
        await client.from('mat_products').insert(product).select().single();
    return Map<String, dynamic>.from(response);
  }

  Future<void> updateStock({
    required String productId,
    required int newStock,
  }) async {
    await client
        .from('mat_products')
        .update({'stock': newStock})
        .eq('id', productId);
  }
}
