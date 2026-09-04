import 'package:supabase_flutter/supabase_flutter.dart';

class MaisonSalesRepository {
  MaisonSalesRepository(this.client);

  final SupabaseClient client;

  Future<String> createSale({
    required String invoiceNumber,
    required double subtotal,
    required double discount,
    required double total,
    required double paidAmount,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('User must be authenticated to create a sale.');
    }

    final sale = await client
        .from('mat_sales')
        .insert({
          'user_id': user.id,
          'invoice_number': invoiceNumber,
          'subtotal': subtotal,
          'discount': discount,
          'total': total,
          'paid_amount': paidAmount,
          'payment_method': paymentMethod,
        })
        .select('id')
        .single();

    final saleId = sale['id'] as String;

    try {
      await client.from('mat_sale_items').insert(
            items
                .map(
                  (item) => {
                    ...item,
                    'sale_id': saleId,
                  },
                )
                .toList(),
          );
    } catch (e) {
      await client.from('mat_sales').delete().eq('id', saleId);
      rethrow;
    }

    return saleId;
  }
}
