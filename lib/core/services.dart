import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repository.dart';
import 'config.dart';

class Services {
  static OportuRepository? _repo;

  static OportuRepository get repo {
    final value = _repo;
    if (value == null) {
      throw StateError('Services.init() debe ejecutarse antes de usar el repositorio.');
    }
    return value;
  }

  static Future<void> init() async {
    if (_repo != null) {
      return;
    }
    if (!AppConfig.backendConfigured) {
      throw StateError(
        'Falta la configuración de Supabase. Oportu no arranca con datos simulados.',
      );
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseClientKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _repo = SupabaseRepository();
  }

  static bool get signedIn =>
      AppConfig.backendConfigured &&
      Supabase.instance.client.auth.currentUser != null;

  static User? get user {
    if (!AppConfig.backendConfigured) {
      return null;
    }
    return Supabase.instance.client.auth.currentUser;
  }
}
