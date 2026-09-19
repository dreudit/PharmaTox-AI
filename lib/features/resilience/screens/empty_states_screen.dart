// =============================================================================
// DRUGS IA - ÉTATS VIDES, MODE HORS-LIGNE & RÉSILIENCE (Écran 12)
// =============================================================================
//
// Écran de démonstration/QA rassemblant les principaux états vides et
// d'erreur de l'application (accessible depuis les réglages en debug).
// Chaque état réel est en pratique affiché directement dans son écran
// d'origine (Bibliothèque vide, historique vide, etc.).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

enum ResilienceStateType { offlineDegraded, emptyChatHistory, emptyLibrary, quotaExceeded, indexingError }

class EmptyStatesScreen extends StatefulWidget {
  const EmptyStatesScreen({super.key});

  @override
  State<EmptyStatesScreen> createState() => _EmptyStatesScreenState();
}

class _EmptyStatesScreenState extends State<EmptyStatesScreen> {
  ResilienceStateType _selectedType = ResilienceStateType.offlineDegraded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildScenarioSelector(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
              child: _buildCurrentStateView(),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.surfaceBackground.withOpacity(0.92),
      scrolledUnderElevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.primaryText), onPressed: () => Navigator.of(context).pop()),
      title: const Text('États & résilience', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16.5, fontWeight: FontWeight.w700, color: AppColors.primaryText, letterSpacing: -0.02)),
    );
  }

  Widget _buildScenarioSelector() {
    final scenarios = [
      (ResilienceStateType.offlineDegraded, 'Hors-ligne'),
      (ResilienceStateType.emptyLibrary, 'Bibliothèque vide'),
      (ResilienceStateType.emptyChatHistory, 'Historique vide'),
      (ResilienceStateType.quotaExceeded, 'Quota atteint'),
      (ResilienceStateType.indexingError, "Échec d'indexation"),
    ];

    return Container(
      height: 42,
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: scenarios.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (type, label) = scenarios[index];
          final isSelected = _selectedType == type;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedType = type);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryText : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: isSelected ? AppColors.primaryText : AppColors.surfaceContainerHigh.withOpacity(0.7)),
              ),
              child: Center(child: Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Colors.white : AppColors.secondaryText))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentStateView() {
    switch (_selectedType) {
      case ResilienceStateType.offlineDegraded:
        return _buildOfflineView();
      case ResilienceStateType.emptyLibrary:
        return _buildGenericEmptyState(
          key: 'emptyLibrary',
          icon: Icons.local_library_outlined,
          iconColor: AppColors.accentTeal,
          title: 'Votre bibliothèque est vide',
          description: "Ajoutez vos protocoles ou monographies pour que l'IA puisse y faire référence avec numéro de page.",
        );
      case ResilienceStateType.emptyChatHistory:
        return _buildGenericEmptyState(
          key: 'emptyChatHistory',
          icon: Icons.chat_bubble_outline_rounded,
          iconColor: AppColors.accentBlue,
          title: 'Aucune question enregistrée',
          description: 'Toutes vos interrogations apparaîtront ici avec horodatage.',
        );
      case ResilienceStateType.quotaExceeded:
        return _buildWarningState(
          key: 'quotaExceeded',
          icon: Icons.speed_rounded,
          title: 'Quota mensuel atteint',
          description: "L'espace d'indexation vectorielle alloué à votre compte est saturé. Supprimez un document ou passez à un palier supérieur.",
        );
      case ResilienceStateType.indexingError:
        return _buildErrorState(
          key: 'indexingError',
          title: "Échec du découpage vectoriel",
          description: "Ce fichier semble protégé par mot de passe ou contient des pages scannées illisibles sans OCR.",
        );
    }
  }

  Widget _buildOfflineView() {
    return SingleChildScrollView(
      key: const ValueKey('offlineDegraded'),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.warningAmberSoft.withOpacity(0.7), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warningAmber.withOpacity(0.4))),
            child: Row(children: const [
              Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.warningAmber),
              SizedBox(width: 10),
              Expanded(child: Text('Connexion réseau indisponible • Mode autonome', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primaryText))),
            ]),
          ),
          const SizedBox(height: 28),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceContainerLowest, border: Border.all(color: AppColors.surfaceContainerHigh, width: 1.5)),
            child: const Center(child: Icon(Icons.cloud_off_rounded, size: 38, color: AppColors.secondaryText)),
          ),
          const SizedBox(height: 20),
          const Text('Mode hors-ligne', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18.5, fontWeight: FontWeight.w700, color: AppColors.primaryText, letterSpacing: -0.02)),
          const SizedBox(height: 8),
          const Text(
            "Vous pouvez continuer à consulter votre historique et vos documents déjà mis en cache.",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.secondaryText, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericEmptyState({required String key, required IconData icon, required Color iconColor, required String title, required String description}) {
    return Center(
      key: ValueKey(key),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, shape: BoxShape.circle, border: Border.all(color: AppColors.surfaceContainerHigh)),
              child: Center(child: Icon(icon, size: 36, color: iconColor)),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryText, letterSpacing: -0.02)),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.secondaryText, height: 1.45)),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningState({required String key, required IconData icon, required String title, required String description}) {
    return Center(
      key: ValueKey(key),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 88, height: 88, decoration: BoxDecoration(color: AppColors.warningAmberSoft, shape: BoxShape.circle), child: Center(child: Icon(icon, size: 38, color: AppColors.warningAmber))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryText, letterSpacing: -0.02)),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.secondaryText, height: 1.45)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState({required String key, required String title, required String description}) {
    return Center(
      key: ValueKey(key),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 88, height: 88, decoration: BoxDecoration(color: AppColors.errorRedSoft, shape: BoxShape.circle), child: const Center(child: Icon(Icons.error_outline_rounded, size: 38, color: AppColors.errorRed))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryText, letterSpacing: -0.02)),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.secondaryText, height: 1.45)),
          ],
        ),
      ),
    );
  }
}
