// Test de fumée minimal : vérifie que la configuration d'environnement de
// l'app est bien renseignée (pas de test de widget complet ici, car
// DrugsIaApp nécessite une session Supabase initialisée au démarrage).

import 'package:flutter_test/flutter_test.dart';

import 'package:drugs_ia_app/core/network/app_config.dart';

void main() {
  test('AppConfig fournit une URL et une clé Supabase non vides', () {
    expect(AppConfig.supabaseUrl, isNotEmpty);
    expect(AppConfig.supabaseAnonKey, isNotEmpty);
    expect(AppConfig.isConfigured, isTrue);
  });
}
