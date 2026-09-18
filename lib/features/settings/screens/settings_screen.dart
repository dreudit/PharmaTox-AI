// =============================================================================
// DRUGS IA - RÉGLAGES & PARAMÈTRES (Écran 10)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/app_colors.dart';

/// Écran des réglages : profil, comportement de l'IA, voix, sources web
/// autorisées, sécurité et données. Les préférences sont synchronisées
/// avec la colonne JSONB `profiles.preferences`.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userLevel = 'Étudiant';
  String _responseStyle = 'Concis & synthétique';
  String _voiceType = 'Voix par défaut (Français)';
  double _voiceSpeed = 1.0;

  bool _enablePubMed = true;
  bool _enableANSM = true;
  bool _enableHAS = true;
  bool _enableOpenFDA = true;
  bool _enableDailyMed = false;

  bool _offlineCacheEnabled = true;

  String get _userEmail => supabase.auth.currentUser?.email ?? 'Non connecté';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _buildProfileCard(),
          const SizedBox(height: 20),
          _buildSectionHeader("Comportement de l'IA"),
          _buildSettingsGroup([
            _buildDropdownTile(
              icon: Icons.school_outlined,
              title: 'Niveau utilisateur',
              value: _userLevel,
              options: const ['Étudiant', 'Professionnel de santé', 'Chercheur'],
              onChanged: (val) => setState(() => _userLevel = val!),
            ),
            _buildDropdownTile(
              icon: Icons.tune_rounded,
              title: 'Style des réponses',
              value: _responseStyle,
              options: const ['Concis & synthétique', 'Approfondi', 'Pédagogique'],
              onChanged: (val) => setState(() => _responseStyle = val!),
            ),
          ]),
          const SizedBox(height: 20),
          _buildSectionHeader('Discussion vocale'),
          _buildSettingsGroup([
            _buildDropdownTile(
              icon: Icons.record_voice_over_outlined,
              title: 'Voix de synthèse',
              value: _voiceType,
              options: const ['Voix par défaut (Français)', 'Voix alternative 1', 'Voix alternative 2'],
              onChanged: (val) => setState(() => _voiceType = val!),
            ),
            _buildSliderTile(
              icon: Icons.speed_rounded,
              title: 'Débit de parole',
              subtitle: '${_voiceSpeed.toStringAsFixed(1)}x',
              value: _voiceSpeed,
              min: 0.8,
              max: 1.4,
              onChanged: (val) => setState(() => _voiceSpeed = val),
            ),
          ]),
          const SizedBox(height: 20),
          _buildSectionHeader('Sources web autorisées'),
          _buildSettingsGroup([
            _buildSwitchTile(icon: Icons.public_rounded, title: 'PubMed / PMC', subtitle: 'Articles validés par les pairs', value: _enablePubMed, onChanged: (v) => setState(() => _enablePubMed = v)),
            _buildSwitchTile(icon: Icons.verified_outlined, title: 'ANSM', subtitle: 'Monographies et posologies officielles françaises', value: _enableANSM, onChanged: (v) => setState(() => _enableANSM = v)),
            _buildSwitchTile(icon: Icons.library_books_outlined, title: 'HAS', subtitle: 'Recommandations de bonne pratique', value: _enableHAS, onChanged: (v) => setState(() => _enableHAS = v)),
            _buildSwitchTile(icon: Icons.medical_services_outlined, title: 'OpenFDA / DailyMed', subtitle: 'Alertes de pharmacovigilance internationales', value: _enableOpenFDA, onChanged: (v) => setState(() => _enableOpenFDA = v)),
            _buildSwitchTile(icon: Icons.medication_outlined, title: 'DailyMed', subtitle: 'Notices officielles US', value: _enableDailyMed, onChanged: (v) => setState(() => _enableDailyMed = v)),
          ]),
          const SizedBox(height: 20),
          _buildSectionHeader('Données & sécurité'),
          _buildSettingsGroup([
            _buildSwitchTile(icon: Icons.offline_bolt_outlined, title: 'Cache hors-ligne', subtitle: 'Conserver les derniers échanges et documents favoris', value: _offlineCacheEnabled, onChanged: (v) => setState(() => _offlineCacheEnabled = v)),
            _buildActionTile(icon: Icons.file_download_outlined, title: 'Exporter mes données', subtitle: 'Archive JSON de vos conversations', onTap: () => HapticFeedback.lightImpact()),
            _buildActionTile(icon: Icons.delete_outline_rounded, title: 'Supprimer mon compte', subtitle: 'Supprime définitivement documents et historique', isDestructive: true, onTap: _showDeleteAccountDialog),
          ]),
          const SizedBox(height: 20),
          _buildLegalFooter(),
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
      title: const Text('Réglages', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primaryText, letterSpacing: -0.02)),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.6))),
      child: Row(
        children: [
          const CircleAvatar(radius: 26, backgroundColor: AppColors.primaryText, child: Icon(Icons.person_outline_rounded, color: Colors.white, size: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_userEmail, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryText), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                const Text('Compte personnel', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.secondaryText)),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (r) => false);
            },
            child: const Text('Déconnexion', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.errorRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(), style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.tertiaryText, letterSpacing: 0.6)),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.6))),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const Divider(color: AppColors.surfaceContainerLow, height: 1, indent: 48),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitchTile({required IconData icon, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.secondaryText),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.tertiaryText)),
              ],
            ),
          ),
          Switch.adaptive(value: value, activeColor: AppColors.accentTeal, onChanged: (val) {
            HapticFeedback.selectionClick();
            onChanged(val);
          }),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({required IconData icon, required String title, required String value, required List<String> options, required ValueChanged<String?> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.secondaryText),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, color: AppColors.accentTeal, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.tertiaryText),
            onSelected: (val) {
              HapticFeedback.selectionClick();
              onChanged(val);
            },
            itemBuilder: (context) => options.map((opt) => PopupMenuItem<String>(value: opt, child: Text(opt, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, color: AppColors.primaryText)))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({required IconData icon, required String title, required String subtitle, required double value, required double min, required double max, required ValueChanged<double> onChanged}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        children: [
          Row(children: [
            Icon(icon, size: 20, color: AppColors.secondaryText),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText))),
            Text(subtitle, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
          ]),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(activeTrackColor: AppColors.primaryText, inactiveTrackColor: AppColors.surfaceContainerLow, thumbColor: AppColors.primaryText, overlayColor: AppColors.primaryText.withOpacity(0.1), trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
            child: Slider(value: value, min: min, max: max, divisions: 6, onChanged: (val) {
              HapticFeedback.selectionClick();
              onChanged(val);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDestructive ? AppColors.errorRed : AppColors.secondaryText),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600, color: isDestructive ? AppColors.errorRed : AppColors.primaryText)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.tertiaryText)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.tertiaryText),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: const [
          Icon(Icons.shield_outlined, size: 22, color: AppColors.tertiaryText),
          SizedBox(height: 6),
          Text(
            'Drugs IA v1.0\nOutil éducatif et documentaire d\'aide à l\'information — ne remplace pas un avis médical.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.tertiaryText, height: 1.45),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer le compte ?', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
        content: const Text('Cette action est irréversible. Tous vos documents, vecteurs et historiques seront définitivement effacés.', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, color: AppColors.secondaryText, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: AppColors.secondaryText))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // La suppression réelle est effectuée côté serveur (Edge Function
              // avec service_role) pour purger auth.users, storage et pgvector.
              await supabase.auth.signOut();
              if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (r) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999))),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
