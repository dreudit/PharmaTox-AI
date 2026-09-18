// Configuration d'environnement : URL et clé publiable ("publishable key")
// du projet Supabase.
//
// La clé publiable (sb_publishable_...) est conçue par Supabase pour être
// embarquée côté client — comme l'ancienne clé anonyme JWT qu'elle remplace,
// elle est sans danger dans une app mobile distribuée : la sécurité repose
// sur les policies Row-Level Security, pas sur le secret de cette clé.
// La valeur par défaut ci-dessous correspond donc au projet Supabase actif
// de Drugs IA. Pour pointer vers un autre projet (dev/staging personnel),
// surchargez au build avec --dart-define :
//
//   flutter run \
//     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
//
// Ne jamais mettre ici la clé "secret" (sb_secret_...) ni un jeton d'accès
// personnel Supabase (sbp_...) : ceux-ci restent uniquement côté serveur
// (Edge Functions secrets), jamais dans l'app ni dans ce dépôt.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pqwdmxuppitudhjgnxnv.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_Z8GBSNUwTviGmit9P2T3RA_-CGHkeNh',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
