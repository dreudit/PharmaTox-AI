import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';

/// Initialise le SDK Supabase une seule fois au démarrage de l'app.
/// Ne fait rien si [AppConfig.isConfigured] est faux : voir main.dart,
/// qui affiche alors l'écran de configuration requise au lieu d'appeler
/// cette fonction.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
}

/// Raccourci vers le client Supabase actif, utilisé dans toute l'app
/// (Auth, Postgres, Storage, Realtime, Edge Functions).
SupabaseClient get supabase => Supabase.instance.client;
