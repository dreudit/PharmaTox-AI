// Configuration d'environnement : URL et clé anonyme Supabase.
// Fournies au build via --dart-define (jamais codées en dur, jamais dans l'app store).
//
// Exemple :
//   flutter run \
//     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Tant que l'URL Supabase du projet n'a pas été fournie, l'app démarre
  /// en mode "configuration requise" plutôt que de planter au lancement.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
