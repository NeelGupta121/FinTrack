import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';
import '../utils/logger.dart';

/// Supabase initialization and client access.
class SupabaseConfig {
  static Future<void> init() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    AppLogger.info('Supabase initialized successfully', tag: 'Supabase');
  }

  static SupabaseClient get client => Supabase.instance.client;
}
