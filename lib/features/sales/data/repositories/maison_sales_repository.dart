import 'package:supabase_flutter/supabase_flutter.dart';

class MaisonSalesRepository {
  MaisonSalesRepository(this.client);

  final SupabaseClient client;

  Future<String> createSale({
    required double discount,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
  }) async {
    if (client.auth.currentUser == null) {
      throw StateError('User must be authenticated to create a sale.');
    }
    if (items.isEmpty) {
      throw ArgumentError('A sale must contain at least one item.');
    }

    final result = await client.rpc(
      'create_sale',
      params: {
        'p_items': items,
        'p_payment_method': paymentMethod,
        'p_discount': discount,
      },
    );

    if (result == null) {
      throw StateError('Supabase did not return a sale result.');
    }

    if (result is Map) {
      final saleId = result['sale_id'];
      if (saleId != null) return saleId.toString();
    }

    throw StateError('Supabase returned an invalid sale result.');
  }
}
