import 'package:supabase_flutter/supabase_flutter.dart';

class MaisonSupabaseConfig {
  static Future<void> initialize({
    required String url,
    required String publishableKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: publishableKey,
    );
  }
}
