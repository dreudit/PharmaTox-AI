// =============================================================================
// TOXIA - CHAT CLINIQUE (Écran 3 & 4 du cahier des charges)
// Connecté au streaming SSE réel (Edge Function `chat`) via Riverpod.
// =============================================================================

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/sse_chat_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared_widgets/floating_capsule_nav.dart';
import '../widgets/sources_bottom_sheet.dart';

enum MessageSender { user, ai }

enum SourceFilterMode { all, libraryRAG, webVerified }

class ChatMessageModel {
  final String id;
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final List<StreamCitation> citations;
  final String? educationalNote;
  final int? latencyMs;
  final bool isStreaming;

  ChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.citations = const [],
    this.educationalNote,
    this.latencyMs,
    this.isStreaming = false,
  });

  ChatMessageModel copyWith({
    String? text,
    List<StreamCitation>? citations,
    String? educationalNote,
    int? latencyMs,
    bool? isStreaming,
  }) {
    return ChatMessageModel(
      id: id,
      sender: sender,
      text: text ?? this.text,
      timestamp: timestamp,
      citations: citations ?? this.citations,
      educationalNote: educationalNote ?? this.educationalNote,
      latencyMs: latencyMs ?? this.latencyMs,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  final String? conversationId;

  const ChatScreen({super.key, this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  SourceFilterMode _selectedFilter = SourceFilterMode.all;
  bool _deepSearch = true; // Mode Approfondi (plusieurs recherches web) vs Rapide (1 recherche)
  int _currentNavIndex = 0;
  String? _activeConversationId;

  final List<ChatMessageModel> _messages = [];

  @override
  void initState() {
    super.initState();
    _activeConversationId = widget.conversationId;
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  String get _sourcesModeString {
    switch (_selectedFilter) {
      case SourceFilterMode.all:
        return 'all';
      case SourceFilterMode.libraryRAG:
        return 'library_only';
      case SourceFilterMode.webVerified:
        return 'web_only';
    }
  }

  Future<void> _handleSendQuery() async {
    final queryText = _textController.text.trim();
    if (queryText.isEmpty) return;

    HapticFeedback.lightImpact();

    final userMessage = ChatMessageModel(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.user,
      text: queryText,
      timestamp: DateTime.now(),
    );

    final aiPlaceholder = ChatMessageModel(
      id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.ai,
      text: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    setState(() {
      _messages.add(userMessage);
      _messages.add(aiPlaceholder);
      _textController.clear();
    });

    _scrollToBottom();

    try {
      await ref.read(chatStreamNotifierProvider.notifier).sendClinicalQuery(
            query: queryText,
            conversationId: _activeConversationId,
            sourcesMode: _sourcesModeString,
            searchMode: _deepSearch ? 'deep' : 'quick',
            onTokenReceived: _scrollToBottom,
            onCompleted: () {
              HapticFeedback.mediumImpact();
              _scrollToBottom();
            },
          );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.errorRed,
          content: Text('Échec de connexion : $err'),
        ),
      );
    }
  }

  void _handleCancelStream() {
    HapticFeedback.heavyImpact();
    ref.read(chatStreamNotifierProvider.notifier).cancelStream();
  }

  void _openSourcesBottomSheet(List<StreamCitation> citations) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SourcesBottomSheet(citations: citations),
    );
  }

  @override
  Widget build(BuildContext context) {
    final streamState = ref.watch(chatStreamNotifierProvider);
    final isStreamingActive = streamState.isBusy;

    if (_messages.isNotEmpty && _messages.last.isStreaming) {
      if (isStreamingActive) {
        _messages[_messages.length - 1] = _messages.last.copyWith(
          text: streamState.accumulatedText,
          citations: streamState.citations,
        );
      } else if (streamState.status == StreamStatus.completed) {
        _messages[_messages.length - 1] = _messages.last.copyWith(
          text: streamState.accumulatedText.isNotEmpty ? streamState.accumulatedText : _messages.last.text,
          citations: streamState.citations.isNotEmpty ? streamState.citations : _messages.last.citations,
          latencyMs: streamState.latencyMs,
          isStreaming: false,
          educationalNote: "Outil éducatif et documentaire. Vérifiez toute posologie sur la monographie officielle.",
        );
        if (_activeConversationId == null && streamState.conversationId != null) {
          _activeConversationId = streamState.conversationId;
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: _buildAppBar(streamState),
      body: Stack(
        children: [
          Column(
            children: [
              _buildSourceFilterBar(),
              if (streamState.status == StreamStatus.error) _buildStreamErrorBanner(streamState.errorMessage),
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 14.0, bottom: 165.0),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _buildMessageBubble(msg, isStreamingActive && index == _messages.length - 1);
                        },
                      ),
              ),
            ],
          ),
          Positioned(left: 0, right: 0, bottom: 84.0, child: _buildInputCapsuleArea(isStreamingActive)),
          FloatingCapsuleNav(
            currentIndex: _currentNavIndex,
            onIndexChanged: (index) {
              HapticFeedback.selectionClick();
              setState(() => _currentNavIndex = index);
              if (index == 1) Navigator.of(context).pushNamed('/library');
              if (index == 2) Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ChatStreamingState streamState) {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.surfaceBackground.withOpacity(0.92),
      scrolledUnderElevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7.5),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.8)),
            ),
            child: const Icon(Icons.healing_rounded, color: AppColors.accentTeal, size: 19),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Drugs IA',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryText, letterSpacing: -0.02),
              ),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: streamState.isBusy ? AppColors.accentBlue : AppColors.accentTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    streamState.isBusy ? 'Réponse en cours...' : 'Prêt',
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.tertiaryText),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded, color: AppColors.secondaryText),
          onPressed: () => Navigator.of(context).pushNamed('/sidebar'),
          tooltip: 'Historique',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  static const List<({String label, String starter, IconData icon, List<Color> gradient})> _quickStarters = [
    (
      label: 'Posologie',
      starter: 'Quelle est la posologie de ',
      icon: Icons.medication_rounded,
      gradient: [Color(0xFF7C3AED), Color(0xFFC026D3)],
    ),
    (
      label: 'Toxidrome',
      starter: 'Décris le toxidrome associé à ',
      icon: Icons.warning_amber_rounded,
      gradient: [Color(0xFFC026D3), Color(0xFFD946EF)],
    ),
    (
      label: 'Interactions',
      starter: 'Quelles sont les interactions médicamenteuses de ',
      icon: Icons.hub_rounded,
      gradient: [Color(0xFF6366F1), Color(0xFF818CF8)],
    ),
    (
      label: 'Antidote',
      starter: 'Quel est l\'antidote en cas d\'intoxication par ',
      icon: Icons.healing_rounded,
      gradient: [Color(0xFF7C3AED), Color(0xFF6366F1)],
    ),
  ];

  void _applyQuickStarter(String starter) {
    HapticFeedback.lightImpact();
    _textController.value = TextEditingValue(text: starter, selection: TextSelection.collapsed(offset: starter.length));
    _inputFocusNode.requestFocus();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: AppColors.heroGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 28, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Posez votre première question',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryText),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pharmacologie, toxicologie, interactions, posologies sourcées.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.15,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final quickStarter in _quickStarters)
                  _buildQuickStarterChip(
                    label: quickStarter.label,
                    icon: quickStarter.icon,
                    gradient: quickStarter.gradient,
                    onTap: () => _applyQuickStarter(quickStarter.starter),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStarterChip({required String label, required IconData icon, required List<Color> gradient, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.7)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryText),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceBackground,
        border: Border(bottom: BorderSide(color: AppColors.surfaceContainerHigh.withOpacity(0.6), width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterPill(
              title: 'Toutes sources',
              icon: Icons.all_inclusive_rounded,
              isSelected: _selectedFilter == SourceFilterMode.all,
              onTap: () => setState(() => _selectedFilter = SourceFilterMode.all),
            ),
            const SizedBox(width: 8),
            _buildFilterPill(
              title: 'Bibliothèque',
              icon: Icons.local_library_outlined,
              isSelected: _selectedFilter == SourceFilterMode.libraryRAG,
              onTap: () => setState(() => _selectedFilter = SourceFilterMode.libraryRAG),
            ),
            const SizedBox(width: 8),
            _buildFilterPill(
              title: 'Web',
              icon: Icons.public_rounded,
              isSelected: _selectedFilter == SourceFilterMode.webVerified,
              onTap: () => setState(() => _selectedFilter = SourceFilterMode.webVerified),
            ),
            if (_selectedFilter != SourceFilterMode.libraryRAG) ...[
              const SizedBox(width: 8),
              Container(width: 1, height: 20, color: AppColors.surfaceContainerHigh),
              const SizedBox(width: 8),
              _buildFilterPill(
                title: _deepSearch ? 'Approfondi' : 'Rapide',
                icon: _deepSearch ? Icons.travel_explore_rounded : Icons.bolt_rounded,
                isSelected: _deepSearch,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _deepSearch = !_deepSearch);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryText : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: isSelected ? AppColors.primaryText : AppColors.surfaceContainerHigh),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : AppColors.secondaryText),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.primaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamErrorBanner(String? errorMessage) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.errorRedSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.errorRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage ?? 'Erreur de streaming.',
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, color: AppColors.errorRed, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg, bool isActivelyStreamingThis) {
    final isUser = msg.sender == MessageSender.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isUser ? AppColors.primaryText : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 20),
              ),
              border: isUser ? null : Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg.text.isEmpty && isActivelyStreamingThis)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.8, valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentTeal)),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Recherche et synthèse en cours...',
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.secondaryText, fontStyle: FontStyle.italic),
                      ),
                    ],
                  )
                else
                  Text(
                    msg.text,
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14.5, height: 1.5, color: isUser ? Colors.white : AppColors.primaryText),
                  ),
                if (!isUser && msg.citations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.surfaceContainerLow, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Sources :', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.tertiaryText)),
                      const SizedBox(width: 6),
                      ...msg.citations.take(4).map((cit) => GestureDetector(
                            onTap: () => _openSourcesBottomSheet(msg.citations),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(color: AppColors.accentBlueSoft, borderRadius: BorderRadius.circular(6)),
                              child: Text('[${cit.citationNumber}]',
                                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.accentBlue)),
                            ),
                          )),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _openSourcesBottomSheet(msg.citations),
                        child: const Text('Examiner →', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentBlue)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!isUser && msg.educationalNote != null) ...[
            const SizedBox(height: 6),
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warningAmberSoft.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warningAmber.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warningAmber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(msg.educationalNote!, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.secondaryText, height: 1.3)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputCapsuleArea(bool isBusy) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.8), width: 1.2),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.secondaryText, size: 21),
                  onPressed: () => Navigator.of(context).pushNamed('/library'),
                  tooltip: 'Joindre un document',
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _inputFocusNode,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => isBusy ? null : _handleSendQuery(),
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: AppColors.primaryText),
                    decoration: const InputDecoration(
                      hintText: 'Posologie, toxidrome, antidote...',
                      hintStyle: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13.5, color: AppColors.tertiaryText),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.mic_none_rounded, color: AppColors.secondaryText, size: 21),
                  onPressed: () => Navigator.of(context).pushNamed('/voice'),
                  tooltip: 'Discussion vocale',
                ),
                GestureDetector(
                  onTap: isBusy ? _handleCancelStream : _handleSendQuery,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: isBusy ? AppColors.errorRed : AppColors.primaryText, shape: BoxShape.circle),
                    child: Icon(isBusy ? Icons.stop_rounded : Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
