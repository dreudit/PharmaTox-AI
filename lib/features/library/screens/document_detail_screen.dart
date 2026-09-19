// =============================================================================
// DRUGS IA - DÉTAIL D'UN DOCUMENT & INSPECTION DES SEGMENTS (Écran 8 — F1)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/app_colors.dart';

class DocumentChunkModel {
  final int chunkIndex;
  final int pageNumber;
  final String sectionTitle;
  final String contentSnippet;
  final int tokenCount;
  final double? similarityScore;

  const DocumentChunkModel({
    required this.chunkIndex,
    required this.pageNumber,
    required this.sectionTitle,
    required this.contentSnippet,
    required this.tokenCount,
    this.similarityScore,
  });
}

/// Écran de détail d'un document : métadonnées, statut, segments vectorisés.
class DocumentDetailScreen extends StatefulWidget {
  final String documentId;
  final String storagePath;
  final String documentTitle;
  final String fileFormat;
  final int pageCount;
  final double sizeInMb;
  final int totalChunks;

  const DocumentDetailScreen({
    super.key,
    required this.documentId,
    required this.storagePath,
    required this.documentTitle,
    this.fileFormat = 'PDF',
    this.pageCount = 0,
    this.sizeInMb = 0,
    this.totalChunks = 0,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  int _selectedTab = 0; // 0 = Segments, 1 = Métadonnées
  final TextEditingController _chunkSearchController = TextEditingController();
  bool _isDeleting = false;

  // TODO: remplacer par une requête Supabase sur `document_chunks`
  // (SELECT ... WHERE document_id = :id ORDER BY chunk_index ASC).
  final List<DocumentChunkModel> _chunks = const [];

  List<DocumentChunkModel> get _filteredChunks {
    final query = _chunkSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _chunks;
    return _chunks.where((c) => c.sectionTitle.toLowerCase().contains(query) || c.contentSnippet.toLowerCase().contains(query)).toList();
  }

  @override
  void dispose() {
    _chunkSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildDocumentSummaryHeader(),
          _buildSegmentedTab(),
          Expanded(child: _selectedTab == 0 ? _buildChunksInspectionView() : _buildMetadataView()),
          _buildBottomActionChatBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.surfaceBackground.withOpacity(0.92),
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.primaryText),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text('Détail du document', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16.5, fontWeight: FontWeight.w700, color: AppColors.primaryText, letterSpacing: -0.02)),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded, color: AppColors.secondaryText), onPressed: () => HapticFeedback.lightImpact(), tooltip: 'Ré-indexer'),
        IconButton(
          icon: _isDeleting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.errorRed))
              : const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
          onPressed: _isDeleting ? null : _confirmDeletionDialog,
          tooltip: 'Supprimer',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDocumentSummaryHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.7))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
            child: Text(widget.fileFormat, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.documentTitle, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.primaryText, height: 1.3)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.accentTeal),
                  const SizedBox(width: 4),
                  const Text('Indexé', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.accentTeal)),
                  const SizedBox(width: 8),
                  Text('• ${widget.totalChunks} segments • ${widget.pageCount} p.', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, color: AppColors.tertiaryText)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(9999)),
        child: Row(children: [
          Expanded(child: _tabButton(0, 'Segments (${widget.totalChunks})')),
          Expanded(child: _tabButton(1, 'Métadonnées')),
        ]),
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final selected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(color: selected ? AppColors.surfaceContainerLowest : Colors.transparent, borderRadius: BorderRadius.circular(9999)),
        child: Center(child: Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.primaryText : AppColors.secondaryText))),
      ),
    );
  }

  Widget _buildChunksInspectionView() {
    if (_chunks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text("Ce document n'a pas encore été indexé.", style: TextStyle(fontFamily: 'Plus Jakarta Sans', color: AppColors.secondaryText)),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.filter_list_rounded, color: AppColors.secondaryText, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _chunkSearchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, color: AppColors.primaryText),
                  decoration: const InputDecoration(hintText: 'Filtrer un passage...', hintStyle: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.tertiaryText), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                ),
              ),
            ]),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            itemCount: _filteredChunks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _buildChunkCard(_filteredChunks[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildChunkCard(DocumentChunkModel chunk) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.6))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.accentBlueSoft, borderRadius: BorderRadius.circular(6)),
                  child: Text('Segment #${chunk.chunkIndex}', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.accentBlue)),
                ),
                const SizedBox(width: 8),
                Text('Page ${chunk.pageNumber}', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
              ]),
              Text('${chunk.tokenCount} tokens', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10.5, color: AppColors.tertiaryText)),
            ],
          ),
          const SizedBox(height: 8),
          Text(chunk.sectionTitle, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
          const SizedBox(height: 4),
          Text(chunk.contentSnippet, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.secondaryText, height: 1.45)),
        ],
      ),
    );
  }

  Widget _buildMetadataView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMetaRow('Format', widget.fileFormat),
        _buildMetaRow('Taille sur disque', '${widget.sizeInMb} Mo'),
        _buildMetaRow('Nombre de pages', '${widget.pageCount} pages'),
        _buildMetaRow('Découpage (chunking)', '~800 tokens • Chevauchement 100'),
        _buildMetaRow('Index vectoriel', 'Supabase pgvector (HNSW)'),
        _buildMetaRow('Isolation', 'Row-Level Security (auth.uid())'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.warningAmberSoft.withOpacity(0.4), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warningAmber.withOpacity(0.3))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.shield_outlined, size: 18, color: AppColors.warningAmber),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'La suppression de ce document purge automatiquement tous ses segments vectoriels (clé étrangère CASCADE).',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, color: AppColors.secondaryText, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, color: AppColors.secondaryText)),
          Text(value, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
        ],
      ),
    );
  }

  Widget _buildBottomActionChatBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, border: Border(top: BorderSide(color: AppColors.surfaceContainerHigh.withOpacity(0.8)))),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryText, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999))),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Discuter de ce document', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  void _confirmDeletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ce document ?', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
        content: const Text('Les segments vectoriels et le fichier associé seront définitivement supprimés.', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, color: AppColors.secondaryText, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: AppColors.secondaryText))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDocument();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999))),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDocument() async {
    setState(() => _isDeleting = true);
    try {
      if (widget.storagePath.isNotEmpty) {
        await supabase.storage.from('documents').remove([widget.storagePath]);
      }
      // Supprime la ligne `documents` ; `document_chunks` est purgé
      // automatiquement via la contrainte de clé étrangère ON DELETE CASCADE.
      await supabase.from('documents').delete().eq('id', widget.documentId);
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de la suppression : $err'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }
}
