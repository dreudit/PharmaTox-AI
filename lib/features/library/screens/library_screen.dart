// =============================================================================
// DRUGS IA - BIBLIOTHÈQUE DE DOCUMENTS (Écran 7 du cahier des charges — F1)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared_widgets/floating_capsule_nav.dart';

enum IngestionStatus { ready, indexing, pending, error }

class LibraryDocumentModel {
  final String id;
  final String title;
  final String category;
  final String fileFormat;
  final int pageCount;
  final double sizeInMb;
  final int chunkCount;
  final DateTime updatedAt;
  final IngestionStatus status;
  final double? indexingProgress;

  const LibraryDocumentModel({
    required this.id,
    required this.title,
    required this.category,
    required this.fileFormat,
    required this.pageCount,
    required this.sizeInMb,
    required this.chunkCount,
    required this.updatedAt,
    required this.status,
    this.indexingProgress,
  });
}

/// Écran Bibliothèque : liste des documents personnels de l'utilisateur,
/// leur statut d'indexation vectorielle et l'ajout de nouveaux fichiers.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Tous';
  int _currentNavIndex = 1;

  final List<String> _categories = const [
    'Tous',
    'Protocoles',
    'Monographies',
    'Toxidromes',
    'Autre',
  ];

  // TODO: remplacer par une requête Supabase sur `documents`
  // (SELECT ... WHERE user_id = auth.uid() ORDER BY created_at DESC).
  final List<LibraryDocumentModel> _documents = const [];

  double get _usedMb => _documents.fold(0.0, (sum, d) => sum + d.sizeInMb);
  static const double _quotaMb = 50.0;

  List<LibraryDocumentModel> get _filteredDocuments {
    final query = _searchController.text.trim().toLowerCase();
    return _documents.where((doc) {
      final matchesCategory = _selectedCategory == 'Tous' || doc.category == _selectedCategory;
      final matchesQuery = query.isEmpty ||
          doc.title.toLowerCase().contains(query) ||
          doc.category.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  void _showUploadModal() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _DocumentUploadBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildStorageQuotaCard()),
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: _buildCategoryFilters()),
              if (_documents.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _buildEmptyLibrary())
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Documents indexés (${_filteredDocuments.length})',
                      style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryText),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 110),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildDocumentCard(_filteredDocuments[index]),
                      childCount: _filteredDocuments.length,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Positioned(
            right: 20,
            bottom: 86,
            child: FloatingActionButton.extended(
              onPressed: _showUploadModal,
              backgroundColor: AppColors.primaryText,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Ajouter un document', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
          FloatingCapsuleNav(
            currentIndex: _currentNavIndex,
            onIndexChanged: (index) {
              setState(() => _currentNavIndex = index);
              if (index == 0) Navigator.of(context).pushNamedAndRemoveUntil('/chat', (r) => false);
              if (index == 2) Navigator.of(context).pushNamed('/settings');
            },
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
      titleSpacing: 16,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bibliothèque', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryText, letterSpacing: -0.02)),
          Text('Vos documents personnels', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.tertiaryText)),
        ],
      ),
    );
  }

  Widget _buildEmptyLibrary() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceContainerHigh),
              ),
              child: const Center(child: Icon(Icons.local_library_outlined, size: 36, color: AppColors.accentTeal)),
            ),
            const SizedBox(height: 20),
            const Text('Votre bibliothèque est vide',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryText, letterSpacing: -0.02)),
            const SizedBox(height: 8),
            const Text(
              "Ajoutez vos protocoles, monographies ou notes pour que l'IA puisse y faire référence avec numéro de page.",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.secondaryText, height: 1.45),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showUploadModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryText,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
              ),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('Téléverser un premier document', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageQuotaCard() {
    final ratio = (_usedMb / _quotaMb).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.accentTealSoft, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.memory_rounded, color: AppColors.accentTeal, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text('Index vectoriel', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
                ],
              ),
              Text('${_usedMb.toStringAsFixed(1)} Mo / ${_quotaMb.toInt()} Mo',
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: AppColors.surfaceContainerLow, valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentTeal)),
          ),
          const SizedBox(height: 6),
          Text('${_documents.length} document(s) ingéré(s)', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.tertiaryText)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.secondaryText, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13.5, color: AppColors.primaryText),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un document...',
                  hintStyle: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.tertiaryText),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = cat == _selectedCategory;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryText : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: isSelected ? AppColors.primaryText : AppColors.surfaceContainerHigh),
              ),
              child: Center(
                child: Text(cat, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.secondaryText)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentCard(LibraryDocumentModel doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).pushNamed('/library/document', arguments: doc),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: doc.fileFormat == 'PDF' ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(doc.fileFormat,
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10, fontWeight: FontWeight.w800, color: doc.fileFormat == 'PDF' ? const Color(0xFFDC2626) : const Color(0xFF0284C7))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.title, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.primaryText, height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${doc.category} • ${doc.pageCount} pages • ${doc.sizeInMb} Mo', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.tertiaryText)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: AppColors.surfaceContainerLow, height: 1),
              const SizedBox(height: 8),
              _buildStatusIndicator(doc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(LibraryDocumentModel doc) {
    switch (doc.status) {
      case IngestionStatus.ready:
        return Row(children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.accentTeal, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('Prêt (${doc.chunkCount} segments)', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentTeal)),
        ]);
      case IngestionStatus.indexing:
        return Row(children: [
          const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.8, valueColor: AlwaysStoppedAnimation<Color>(AppColors.warningAmber))),
          const SizedBox(width: 6),
          Text('Indexation (${((doc.indexingProgress ?? 0.5) * 100).toInt()}%)', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warningAmber)),
        ]);
      case IngestionStatus.pending:
        return const Row(children: [
          Icon(Icons.schedule_rounded, size: 12, color: AppColors.tertiaryText),
          SizedBox(width: 6),
          Text("En file d'attente", style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.tertiaryText)),
        ]);
      case IngestionStatus.error:
        return const Row(children: [
          Icon(Icons.error_outline_rounded, size: 12, color: AppColors.errorRed),
          SizedBox(width: 6),
          Text('Échec de découpage', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.errorRed)),
        ]);
    }
  }
}

/// Bottom Sheet pour l'import d'un nouveau document PDF/DOCX/TXT.
class _DocumentUploadBottomSheet extends StatelessWidget {
  const _DocumentUploadBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Ajouter un document', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
          const SizedBox(height: 6),
          const Text(
            'Les documents sont découpés en segments de ~800 tokens et indexés pour être interrogés dans le chat.',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.secondaryText, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceContainerHigh)),
            child: Column(children: const [
              Icon(Icons.cloud_upload_outlined, size: 36, color: AppColors.accentTeal),
              SizedBox(height: 8),
              Text('Sélectionner un PDF, DOCX ou TXT', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
              SizedBox(height: 4),
              Text('Taille max : 50 Mo par fichier', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.tertiaryText)),
            ]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
