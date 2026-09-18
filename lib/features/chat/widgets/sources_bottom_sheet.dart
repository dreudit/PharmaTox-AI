// =============================================================================
// TOXIA - BOTTOM SHEET DES SOURCES & CITATIONS (Écran 9 du cahier des charges)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/network/sse_chat_client.dart' show StreamCitation, CitationOriginType;

/// Modal Bottom Sheet listant les références (document ou URL) citées dans
/// une réponse : onglets Toutes / Bibliothèque RAG / Web.
class SourcesBottomSheet extends StatefulWidget {
  final List<StreamCitation> citations;

  const SourcesBottomSheet({super.key, required this.citations});

  @override
  State<SourcesBottomSheet> createState() => _SourcesBottomSheetState();
}

class _SourcesBottomSheetState extends State<SourcesBottomSheet> {
  int _activeTab = 0; // 0 = Toutes, 1 = Bibliothèque RAG, 2 = Web

  List<StreamCitation> get _filtered {
    if (_activeTab == 1) {
      return widget.citations.where((c) => c.type == CitationOriginType.ragDocument).toList();
    } else if (_activeTab == 2) {
      return widget.citations
          .where((c) =>
              c.type == CitationOriginType.webMedical || c.type == CitationOriginType.officialAgency)
          .toList();
    }
    return widget.citations;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          _buildHeader(context),
          _buildSegmentedFilter(),
          const Divider(color: AppColors.surfaceContainerLow, height: 1),
          Expanded(
            child: widget.citations.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Aucune citation enregistrée pour ce message.",
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', color: AppColors.secondaryText),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildCitationCard(_filtered[index]),
                  ),
          ),
          _buildBottomAuditBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.accentBlueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, size: 18, color: AppColors.accentBlue),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sources & Citations',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                      letterSpacing: -0.02,
                    ),
                  ),
                  Text(
                    '${widget.citations.length} référence(s) pour cette réponse',
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, color: AppColors.tertiaryText),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.secondaryText),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          children: [
            _buildTabItem(0, "Toutes (${widget.citations.length})"),
            _buildTabItem(1, "Bibliothèque"),
            _buildTabItem(2, "Web"),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceContainerLowest : Colors.transparent,
            borderRadius: BorderRadius.circular(9999),
            boxShadow: isSelected
                ? [BoxShadow(color: AppColors.primaryText.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCitationCard(StreamCitation citation) {
    final bool isRag = citation.type == CitationOriginType.ragDocument;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.8)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlueSoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.accentBlue.withOpacity(0.3), width: 0.8),
                    ),
                    child: Text(
                      '[${citation.citationNumber}]',
                      style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.accentBlue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isRag ? AppColors.accentTealSoft : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isRag ? Icons.description_outlined : Icons.public_rounded,
                            size: 11, color: isRag ? AppColors.accentTeal : AppColors.secondaryText),
                        const SizedBox(width: 4),
                        Text(
                          isRag ? 'Bibliothèque' : 'Web',
                          style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isRag ? AppColors.accentTeal : AppColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (citation.relevanceScore != null)
                Text(
                  '${(citation.relevanceScore! * 100).toInt()}% pertinence',
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10.5, color: AppColors.secondaryText),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            citation.title,
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.primaryText, height: 1.35),
          ),
          if ((citation.subtitleOrAuthor ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              isRag && citation.pageNumber != null
                  ? '${citation.subtitleOrAuthor} • Page ${citation.pageNumber}'
                  : citation.subtitleOrAuthor!,
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, color: AppColors.tertiaryText),
            ),
          ],
          if (citation.excerptText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.6)),
              ),
              child: Text(
                '« ${citation.excerptText} »',
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.primaryText, height: 1.45, fontStyle: FontStyle.italic),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                citation.publicationDate != null ? 'Date : ${citation.publicationDate}' : '',
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10.5, color: AppColors.tertiaryText),
              ),
              if (!isRag && citation.url != null)
                InkWell(
                  onTap: () => launchUrl(Uri.parse(citation.url!), mode: LaunchMode.externalApplication),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 13, color: AppColors.accentBlue),
                        SizedBox(width: 4),
                        Text(
                          "Consulter l'article →",
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentBlue),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAuditBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceBackground,
        border: Border(top: BorderSide(color: AppColors.surfaceContainerHigh.withOpacity(0.8))),
      ),
      child: Row(
        children: const [
          Icon(Icons.verified_user_outlined, size: 15, color: AppColors.accentTeal),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "Chaque citation est rattachée à son extrait vectoriel ou à sa source web d'origine.",
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10.5, color: AppColors.secondaryText, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
