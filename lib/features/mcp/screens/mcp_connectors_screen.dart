// =============================================================================
// DRUGS IA - CONNECTEURS MCP (Écran 11 — Phase 2 du cahier des charges)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../models/mcp_server_model.dart';

/// Écran de gestion des serveurs MCP distants (phase 2). L'app mobile
/// n'appelle jamais un serveur MCP directement : tout transite par
/// l'Edge Function `mcp-proxy` avec jetons chiffrés côté serveur.
class McpConnectorsScreen extends StatefulWidget {
  const McpConnectorsScreen({super.key});

  @override
  State<McpConnectorsScreen> createState() => _McpConnectorsScreenState();
}

class _McpConnectorsScreenState extends State<McpConnectorsScreen> {
  // TODO: remplacer par une requête Supabase sur `mcp_servers`
  // (SELECT ... WHERE user_id = auth.uid()).
  final List<McpServerModel> _servers = [];

  void _openAddServerSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddMcpServerBottomSheet(onServerAdded: (newServer) => setState(() => _servers.add(newServer))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _servers.where((s) => s.isEnabled).length;

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: [
          _buildArchitectureCard(),
          const SizedBox(height: 18),
          _buildStatusBar(activeCount),
          const SizedBox(height: 16),
          _buildSectionHeader('SERVEURS CONFIGURÉS (${_servers.length})'),
          if (_servers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aucun serveur MCP configuré pour le moment.',
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, color: AppColors.secondaryText),
              ),
            )
          else
            for (final server in _servers) ...[_buildServerCard(server), const SizedBox(height: 12)],
          const SizedBox(height: 12),
          _buildAddServerButton(),
          const SizedBox(height: 24),
          _buildSecurityNotice(),
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
      title: const Column(children: [
        Text('Connecteurs MCP', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16.5, fontWeight: FontWeight.w700, color: AppColors.primaryText, letterSpacing: -0.02)),
        Text('Model Context Protocol • Phase 2', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.tertiaryText)),
      ]),
    );
  }

  Widget _buildArchitectureCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.7))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: AppColors.accentBlueSoft, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.hub_outlined, size: 18, color: AppColors.accentBlue)),
            const SizedBox(width: 10),
            const Expanded(child: Text('Architecture distante sécurisée', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.primaryText))),
          ]),
          const SizedBox(height: 10),
          const Text(
            "L'application mobile n'appelle aucun serveur MCP en direct. Toutes les requêtes transitent par l'Edge Function 'mcp-proxy' avec contrôle d'accès strict.",
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.secondaryText, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(int activeCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.6))),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accentTeal, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('$activeCount connecteur(s) actif(s)', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
      ]),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.tertiaryText, letterSpacing: 0.6)),
    );
  }

  Widget _buildServerCard(McpServerModel server) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceContainerHigh)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(server.name, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, fontWeight: FontWeight.w700, color: server.isEnabled ? AppColors.primaryText : AppColors.secondaryText)),
                    const SizedBox(height: 3),
                    Text(server.hostUrl, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.tertiaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Switch.adaptive(
                value: server.isEnabled,
                activeColor: AppColors.accentTeal,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    server.isEnabled = val;
                    server.status = val ? McpServerStatus.active : McpServerStatus.inactive;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(server.description, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.secondaryText, height: 1.4)),
          if (server.availableTools.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: server.availableTools.map((tool) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(6)),
                child: Text(tool, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddServerButton() {
    return InkWell(
      onTap: _openAddServerSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLow.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceContainerHigh, width: 1.2)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
          Icon(Icons.add_link_rounded, size: 20, color: AppColors.primaryText),
          SizedBox(width: 8),
          Text('Ajouter un serveur MCP distant', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
        ]),
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceContainerHigh)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Icon(Icons.security_rounded, size: 18, color: AppColors.accentTeal),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            "Les jetons d'authentification des serveurs MCP sont stockés dans Supabase Vault et injectés dynamiquement lors des appels d'outils. Aucun jeton n'est exposé côté client.",
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.secondaryText, height: 1.45),
          ),
        ),
      ]),
    );
  }
}

class _AddMcpServerBottomSheet extends StatefulWidget {
  final ValueChanged<McpServerModel> onServerAdded;

  const _AddMcpServerBottomSheet({required this.onServerAdded});

  @override
  State<_AddMcpServerBottomSheet> createState() => _AddMcpServerBottomSheetState();
}

class _AddMcpServerBottomSheetState extends State<_AddMcpServerBottomSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  bool _readOnly = true;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Connecter un serveur MCP distant', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
          const SizedBox(height: 16),
          _buildField('Nom du service', _nameController, 'Ex : PubMed'),
          const SizedBox(height: 12),
          _buildField("URL du point d'accès", _urlController, 'https://mcp.exemple.fr/v1'),
          const SizedBox(height: 12),
          _buildField("Jeton d'autorisation (secret)", _tokenController, 'mcp_sk_...', isObscure: true),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Mode lecture seule', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
            Switch.adaptive(value: _readOnly, activeColor: AppColors.accentTeal, onChanged: (val) => setState(() => _readOnly = val)),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty && _urlController.text.isNotEmpty) {
                  widget.onServerAdded(McpServerModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: _nameController.text.trim(),
                    hostUrl: _urlController.text.trim(),
                    description: 'Serveur MCP externe configuré par l\'utilisateur.',
                    availableTools: const [],
                    isEnabled: true,
                    isReadOnly: _readOnly,
                    status: McpServerStatus.connecting,
                  ));
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryText, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999))),
              child: const Text('Enregistrer le connecteur', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {bool isObscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.secondaryText)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
          child: TextField(
            controller: controller,
            obscureText: isObscure,
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.primaryText),
            decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.tertiaryText), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10)),
          ),
        ),
      ],
    );
  }
}
