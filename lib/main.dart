// =============================================================================
// DRUGS IA - POINT D'ENTRÉE DE L'APPLICATION
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/app_config.dart';
import 'core/network/supabase_client.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/chat/screens/sidebar_history_screen.dart';
import 'features/library/screens/document_detail_screen.dart';
import 'features/library/screens/library_screen.dart' show LibraryScreen, LibraryDocumentModel;
import 'features/mcp/screens/mcp_connectors_screen.dart';
import 'features/resilience/screens/empty_states_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/voice/screens/voice_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.isConfigured) {
    await initSupabase();
  }

  runApp(const ProviderScope(child: DrugsIaApp()));
}

class DrugsIaApp extends StatelessWidget {
  const DrugsIaApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isConfigured) {
      return MaterialApp(
        title: 'Drugs IA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const _SupabaseSetupRequiredScreen(),
      );
    }

    return MaterialApp(
      title: 'Drugs IA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: _initialRoute,
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/chat': (context) => const ChatScreen(),
        '/sidebar': (context) => const SidebarHistoryScreen(),
        '/library': (context) => const LibraryScreen(),
        '/voice': (context) => const VoiceScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/mcp': (context) => const McpConnectorsScreen(),
        '/resilience': (context) => const EmptyStatesScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/library/document') {
          final doc = settings.arguments is LibraryDocumentModel ? settings.arguments as LibraryDocumentModel : null;
          return MaterialPageRoute(
            builder: (context) => DocumentDetailScreen(
              documentTitle: doc?.title ?? 'Document',
              fileFormat: doc?.fileFormat ?? 'PDF',
              pageCount: doc?.pageCount ?? 0,
              sizeInMb: doc?.sizeInMb ?? 0,
              totalChunks: doc?.chunkCount ?? 0,
            ),
          );
        }
        return null;
      },
    );
  }

  String get _initialRoute => supabase.auth.currentSession != null ? '/chat' : '/onboarding';
}

/// Affiché tant que le projet Supabase n'a pas été branché
/// (--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...).
class _SupabaseSetupRequiredScreen extends StatelessWidget {
  const _SupabaseSetupRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceContainerHigh),
                  ),
                  child: const Center(child: Icon(Icons.dns_outlined, size: 36, color: AppColors.accentTeal)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Configuration Supabase requise',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryText),
                ),
                const SizedBox(height: 10),
                const Text(
                  "L'URL et la clé anonyme du projet Supabase n'ont pas encore été fournies. "
                  "Lancez l'application avec :\n\n"
                  "flutter run \\\n"
                  "  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \\\n"
                  "  --dart-define=SUPABASE_ANON_KEY=eyJ...",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, color: AppColors.secondaryText, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
