import 'package:supabase_flutter/supabase_flutter.dart';

class CashRegisterService {
  final SupabaseClient db;
  CashRegisterService(this.db);

  Future<Map<String, dynamic>?> openShift(double openingCash) async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) throw Exception('Authentication required');
    final existing = await currentShift();
    if (existing != null) return existing;
    final row = await db.from('cash_register_shifts').insert({'user_id': uid, 'opened_by': uid, 'opening_cash': openingCash}).select().single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>?> currentShift() async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await db.from('cash_register_shifts').select().eq('user_id', uid).eq('status', 'open').order('opened_at', ascending: false).limit(1).maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> closeShift({required String shiftId, required double actualCash, String? notes}) async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) throw Exception('Authentication required');
    final shift = await db.from('cash_register_shifts').select('opening_cash,opened_at').eq('id', shiftId).eq('user_id', uid).single();
    final opening = (shift['opening_cash'] as num).toDouble();
    final openedAt = DateTime.parse('${shift['opened_at']}').toUtc();
    final sales = await db.from('sales').select('total,payment_method').eq('user_id', uid).eq('payment_method', 'cash').gte('created_at', openedAt.toIso8601String());
    final expected = opening + sales.fold<double>(0, (sum, row) => sum + ((row['total'] as num?)?.toDouble() ?? 0));
    await db.from('cash_register_shifts').update({'status': 'closed','closed_at': DateTime.now().toUtc().toIso8601String(),'closed_by': uid,'expected_cash': expected,'actual_cash': actualCash,'difference': actualCash - expected,'notes': notes}).eq('id', shiftId).eq('user_id', uid);
  }
}
