// =============================================================================
// TOXIA - ONBOARDING & DÉCHARGE MÉDICALE (Écrans 1, 2 & 3 du cahier des charges)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/app_colors.dart';

/// Écran d'Onboarding en 3 étapes :
/// 1. Présentation de la mission (RAG + Web sourcé + Voix)
/// 2. Décharge médicale & consentement légal
/// 3. Authentification (email / Google) via Supabase Auth
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _understandsEducationalTool = false;
  bool _agreesEmergencyProtocol = false;
  bool _agreesDataConsent = false;

  bool get _isDisclaimerValid =>
      _understandsEducationalTool && _agreesEmergencyProtocol && _agreesDataConsent;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSigningIn = false;
  String? _authError;

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _recordLegalConsent() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase.from('profiles').update({
      'legal_disclaimer_accepted_at': DateTime.now().toIso8601String(),
      'hds_consent_accepted_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
  }

  Future<void> _signInWithEmail() async {
    setState(() {
      _isSigningIn = true;
      _authError = null;
    });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      try {
        await supabase.auth.signInWithPassword(email: email, password: password);
      } on AuthException {
        await supabase.auth.signUp(email: email, password: password);
      }
      await _recordLegalConsent();
      if (mounted) Navigator.of(context).pushReplacementNamed('/chat');
    } catch (err) {
      setState(() => _authError = "Échec de connexion : $err");
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
      _authError = null;
    });
    try {
      await supabase.auth.signInWithOAuth(OAuthProvider.google);
    } catch (err) {
      setState(() => _authError = "Connexion Google indisponible : $err");
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopNavigationHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildStep1Mission(),
                  _buildStep2Disclaimer(),
                  _buildStep3Authentication(),
                ],
              ),
            ),
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavigationHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: AppColors.primaryText),
              onPressed: _previousPage,
              tooltip: 'Retour',
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.surfaceContainerHigh.withOpacity(0.8),
                    ),
                  ),
                  child: const Icon(Icons.healing_rounded,
                      size: 18, color: AppColors.accentTeal),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Drugs IA',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                    letterSpacing: -0.02,
                  ),
                ),
              ],
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.8)),
            ),
            child: Text(
              'Étape ${_currentPage + 1} sur 3',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 1 : MISSION
  // ---------------------------------------------------------------------------
  Widget _buildStep1Mission() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accentTealSoft,
                  AppColors.accentBlueSoft.withOpacity(0.4),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceContainerHigh, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentTeal.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 32, color: AppColors.accentTeal),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "L'intelligence clinique au service de la pharmacologie et de la toxicologie",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
              letterSpacing: -0.02,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Un assistant rigoureux, conçu exclusivement pour la pharmacologie et la toxicologie.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              color: AppColors.secondaryText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          _buildMissionFeatureCard(
            icon: Icons.local_library_outlined,
            iconColor: AppColors.accentTeal,
            title: "Votre bibliothèque personnelle (RAG)",
            description:
                "Vos PDF, DOCX et notes sont indexés et cités avec numéro de page, isolés par Row-Level Security.",
          ),
          const SizedBox(height: 12),
          _buildMissionFeatureCard(
            icon: Icons.public_rounded,
            iconColor: AppColors.accentBlue,
            title: "Recherche Web médicale sourcée",
            description:
                "Validation en direct sur PubMed, ANSM, HAS, OpenFDA. Aucune affirmation clinique importante sans citation.",
          ),
          const SizedBox(height: 12),
          _buildMissionFeatureCard(
            icon: Icons.graphic_eq_rounded,
            iconColor: const Color(0xFF6366F1),
            title: "Mode vocal mains libres",
            description:
                "Interrogez ToxIA à la voix, avec synthèse vocale naturelle et interruption fluide.",
          ),
        ],
      ),
    );
  }

  Widget _buildMissionFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    color: AppColors.secondaryText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 2 : DÉCHARGE MÉDICALE
  // ---------------------------------------------------------------------------
  Widget _buildStep2Disclaimer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warningAmberSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_outlined, size: 22, color: AppColors.warningAmber),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Avertissement médical',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    Text(
                      'Validation obligatoire avant toute utilisation',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceContainerHigh),
            ),
            child: const Text(
              "ToxIA est un outil éducatif et documentaire d'aide à l'information. Il ne constitue ni un dispositif médical, ni un substitut à l'évaluation clinique d'un professionnel de santé habilité ou aux recommandations d'un centre antipoison.",
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12.5,
                color: AppColors.primaryText,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "ENGAGEMENTS DE L'UTILISATEUR",
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.tertiaryText,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          _buildConsentCheckboxTile(
            value: _understandsEducationalTool,
            title: "Outil documentaire non prescriptif",
            subtitle:
                "Je reconnais que les posologies et protocoles doivent être vérifiés sur les monographies officielles (RCP).",
            onChanged: (val) => setState(() => _understandsEducationalTool = val ?? false),
          ),
          const SizedBox(height: 8),
          _buildConsentCheckboxTile(
            value: _agreesEmergencyProtocol,
            title: "Priorité absolue aux secours en urgence",
            subtitle:
                "En situation d'urgence vitale, je m'engage à alerter sans délai les secours ou un centre antipoison local.",
            onChanged: (val) => setState(() => _agreesEmergencyProtocol = val ?? false),
          ),
          const SizedBox(height: 8),
          _buildConsentCheckboxTile(
            value: _agreesDataConsent,
            title: "Confidentialité des données",
            subtitle:
                "J'accepte le traitement chiffré de mes requêtes et m'engage à ne saisir aucune donnée nominative de tiers.",
            onChanged: (val) => setState(() => _agreesDataConsent = val ?? false),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCheckboxTile({
    required bool value,
    required String title,
    required String subtitle,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? AppColors.accentTeal : AppColors.surfaceContainerHigh.withOpacity(0.6),
          width: value ? 1.2 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (val) {
          HapticFeedback.selectionClick();
          onChanged(val);
        },
        activeColor: AppColors.accentTeal,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryText,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 11,
              color: AppColors.secondaryText,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 3 : AUTHENTIFICATION
  // ---------------------------------------------------------------------------
  Widget _buildStep3Authentication() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          const Text(
            'Connexion sécurisée',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
              letterSpacing: -0.02,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Accédez à votre bibliothèque et à votre historique de conversations.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.secondaryText),
          ),
          const SizedBox(height: 24),
          _buildOAuthButton(
            label: 'Continuer avec Google',
            icon: Icons.g_mobiledata_rounded,
            onTap: _isSigningIn ? null : _signInWithGoogle,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.surfaceContainerHigh)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('ou par email',
                    style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.tertiaryText)),
              ),
              const Expanded(child: Divider(color: AppColors.surfaceContainerHigh)),
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField(_emailController, 'vous@exemple.fr', Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 10),
          _buildTextField(_passwordController, 'Mot de passe', Icons.lock_outline_rounded,
              obscureText: true),
          if (_authError != null) ...[
            const SizedBox(height: 10),
            Text(_authError!,
                style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, color: AppColors.errorRed)),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentTealSoft.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentTeal.withOpacity(0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.verified_user_outlined, size: 16, color: AppColors.accentTeal),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Vos données sont isolées par utilisateur (Row-Level Security Supabase).",
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      color: AppColors.accentTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13.5, color: AppColors.primaryText),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.tertiaryText),
          icon: Icon(icon, size: 18, color: AppColors.secondaryText),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _buildOAuthButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceContainerHigh),
          boxShadow: [
            BoxShadow(color: AppColors.primaryText.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.primaryText),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final bool canProceed = _currentPage != 1 || _isDisclaimerValid;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceBackground,
        border: Border(top: BorderSide(color: AppColors.surfaceContainerHigh.withOpacity(0.7))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: List.generate(3, (index) {
              final bool isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 6),
                width: isActive ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryText : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(9999),
                ),
              );
            }),
          ),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: !canProceed || _isSigningIn
                  ? null
                  : _currentPage == 2
                      ? _signInWithEmail
                      : _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryText,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.surfaceContainerHigh,
                disabledForegroundColor: AppColors.tertiaryText,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
              ),
              child: _isSigningIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == 0
                              ? 'Continuer'
                              : _currentPage == 1
                                  ? "J'accepte"
                                  : 'Accéder à Drugs IA',
                          style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
