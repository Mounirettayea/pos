import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration for the Maison Al Teeb mobile app.
///
/// Pass the values at build time:
/// flutter build apk --release \
///   --dart-define=SUPABASE_URL=... \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=...
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static Future<void> initialize() async {
    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY. '
        'Provide them with --dart-define when building the app.',
      );
    }

    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
