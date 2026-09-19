// =============================================================================
// DRUGS IA - SIDEBAR & HISTORIQUE DES CONVERSATIONS (Écran 5 du cahier des charges)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

class ConversationModel {
  final String id;
  final String title;
  final String previewSnippet;
  final DateTime updatedAt;
  final int messageCount;
  final bool hasRAGSources;
  final bool isPinned;

  const ConversationModel({
    required this.id,
    required this.title,
    required this.previewSnippet,
    required this.updatedAt,
    required this.messageCount,
    this.hasRAGSources = false,
    this.isPinned = false,
  });
}

/// Écran / tiroir de l'historique des conversations, groupé par date.
class SidebarHistoryScreen extends StatefulWidget {
  final VoidCallback? onNewChatRequested;
  final ValueChanged<String>? onConversationSelected;

  const SidebarHistoryScreen({
    super.key,
    this.onNewChatRequested,
    this.onConversationSelected,
  });

  @override
  State<SidebarHistoryScreen> createState() => _SidebarHistoryScreenState();
}

class _SidebarHistoryScreenState extends State<SidebarHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _activeFilter = 'Toutes';

  // TODO: remplacer par une requête Supabase sur `conversations`
  // (SELECT ... WHERE user_id = auth.uid() ORDER BY updated_at DESC).
  final List<ConversationModel> _allConversations = const [];

  List<ConversationModel> get _filteredConversations {
    final query = _searchController.text.trim().toLowerCase();
    return _allConversations.where((conv) {
      final matchesQuery = query.isEmpty ||
          conv.title.toLowerCase().contains(query) ||
          conv.previewSnippet.toLowerCase().contains(query);
      if (_activeFilter == 'Épinglées') return matchesQuery && conv.isPinned;
      if (_activeFilter == 'Avec RAG') return matchesQuery && conv.hasRAGSources;
      return matchesQuery;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayList = _filteredConversations.where((c) => now.difference(c.updatedAt).inHours < 24).toList();
    final weekList = _filteredConversations.where((c) {
      final diff = now.difference(c.updatedAt);
      return diff.inHours >= 24 && diff.inDays <= 7;
    }).toList();
    final olderList = _filteredConversations.where((c) => now.difference(c.updatedAt).inDays > 7).toList();

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildSidebarHeader(),
            _buildSearchField(),
            _buildQuickPillFilters(),
            const SizedBox(height: 8),
            Expanded(
              child: _filteredConversations.isEmpty
                  ? _buildEmptyHistory()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      children: [
                        if (todayList.isNotEmpty) ..._buildGroup("Aujourd'hui", todayList),
                        if (weekList.isNotEmpty) ..._buildGroup('7 derniers jours', weekList),
                        if (olderList.isNotEmpty) ..._buildGroup('Plus ancien', olderList),
                      ],
                    ),
            ),
            _buildBottomProfileCard(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroup(String title, List<ConversationModel> items) {
    return [
      _buildSectionHeader(title),
      ...items.map(_buildConversationTile),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.tertiaryText),
            const SizedBox(height: 12),
            const Text(
              'Aucune conversation',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryText),
            ),
            const SizedBox(height: 6),
            const Text(
              'Vos échanges apparaîtront ici, regroupés par date.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                if (widget.onNewChatRequested != null) {
                  widget.onNewChatRequested!();
                } else {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryText,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Nouvelle conversation',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: AppColors.secondaryText, size: 22),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.secondaryText, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.primaryText),
                decoration: const InputDecoration(
                  hintText: 'Rechercher une conversation...',
                  hintStyle: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, color: AppColors.tertiaryText),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() {});
                },
                child: const Icon(Icons.close_rounded, size: 16, color: AppColors.secondaryText),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPillFilters() {
    final filters = ['Toutes', 'Épinglées', 'Avec RAG'];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      height: 30,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = filter == _activeFilter;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _activeFilter = filter);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.surfaceContainerLowest : Colors.transparent,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: isSelected ? AppColors.primaryText.withOpacity(0.2) : Colors.transparent),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.tertiaryText, letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildConversationTile(ConversationModel conv) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onConversationSelected?.call(conv.id);
          Navigator.of(context).pop();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  conv.isPinned ? Icons.push_pin_rounded : Icons.chat_bubble_outline_rounded,
                  size: 15,
                  color: conv.isPinned ? AppColors.warningAmber : AppColors.secondaryText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(conv.title,
                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(conv.previewSnippet,
                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, color: AppColors.secondaryText),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (conv.hasRAGSources)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.accentTealSoft, borderRadius: BorderRadius.circular(4)),
                  child: const Text('RAG', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.accentTeal)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomProfileCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.surfaceContainerHigh.withOpacity(0.8))),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryText,
            child: Icon(Icons.person_outline_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Mon profil', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
                Text('Voir les réglages', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.tertiaryText)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.secondaryText, size: 20),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/settings');
            },
            tooltip: 'Réglages',
          ),
        ],
      ),
    );
  }
}
