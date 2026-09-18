// =============================================================================
// TOXIA CLINICAL INTELLIGENCE - CLIENT STREAMING SSE & PROVIDER RIVERPOD
// Rôle : appelle l'Edge Function Supabase `chat` et expose un flux d'état
// réactif consommé par l'écran de Chat (Server-Sent Events).
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

// -----------------------------------------------------------------------------
// 1. MODÈLES DE DONNÉES TYPÉS POUR LE FLUX SSE
// -----------------------------------------------------------------------------

enum CitationOriginType { ragDocument, webMedical, officialAgency }

/// Citation structurée retournée lors des événements SSE 'init' ou 'done'.
class StreamCitation {
  final int citationNumber;
  final CitationOriginType type;
  final String title;
  final String? subtitleOrAuthor;
  final String? documentName;
  final int? pageNumber;
  final String? sectionTitle;
  final String? url;
  final String? publicationDate;
  final double? relevanceScore;
  final String excerptText;

  const StreamCitation({
    required this.citationNumber,
    required this.type,
    required this.title,
    this.subtitleOrAuthor,
    this.documentName,
    this.pageNumber,
    this.sectionTitle,
    this.url,
    this.publicationDate,
    this.relevanceScore,
    this.excerptText = '',
  });

  factory StreamCitation.fromJson(Map<String, dynamic> json) {
    CitationOriginType parseType(String? t) {
      if (t == 'rag') return CitationOriginType.ragDocument;
      if (t == 'web') return CitationOriginType.webMedical;
      return CitationOriginType.officialAgency;
    }

    return StreamCitation(
      citationNumber: json['citationNumber'] as int? ?? 1,
      type: parseType(json['type'] as String?),
      title: json['title'] as String? ?? 'Référence clinique',
      subtitleOrAuthor: json['subtitleOrAuthor'] as String?,
      documentName: json['documentName'] as String?,
      pageNumber: json['pageNumber'] as int?,
      sectionTitle: json['sectionTitle'] as String?,
      url: json['url'] as String?,
      publicationDate: json['publicationDate'] as String?,
      relevanceScore: (json['relevanceScore'] as num?)?.toDouble(),
      excerptText: json['excerptText'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'citationNumber': citationNumber,
        'type': type == CitationOriginType.ragDocument ? 'rag' : 'web',
        'title': title,
        'subtitleOrAuthor': subtitleOrAuthor,
        'documentName': documentName,
        'pageNumber': pageNumber,
        'sectionTitle': sectionTitle,
        'url': url,
        'publicationDate': publicationDate,
        'relevanceScore': relevanceScore,
        'excerptText': excerptText,
      };
}

abstract class ChatStreamEvent {
  const ChatStreamEvent();
}

class ChatInitEvent extends ChatStreamEvent {
  final String conversationId;
  final String messageId;
  final List<StreamCitation> citations;
  final int sourcesCount;

  const ChatInitEvent({
    required this.conversationId,
    required this.messageId,
    required this.citations,
    required this.sourcesCount,
  });
}

class ChatDeltaEvent extends ChatStreamEvent {
  final String deltaText;
  const ChatDeltaEvent(this.deltaText);
}

class ChatDoneEvent extends ChatStreamEvent {
  final String conversationId;
  final String messageId;
  final int totalLength;
  final int latencyMs;
  final List<StreamCitation> citations;

  const ChatDoneEvent({
    required this.conversationId,
    required this.messageId,
    required this.totalLength,
    required this.latencyMs,
    required this.citations,
  });
}

class ChatErrorEvent extends ChatStreamEvent {
  final String error;
  const ChatErrorEvent(this.error);
}

// -----------------------------------------------------------------------------
// 2. ÉTAT RÉACTIF DE STREAMING (RIVERPOD)
// -----------------------------------------------------------------------------

enum StreamStatus { idle, connecting, streaming, completed, error }

class ChatStreamingState {
  final StreamStatus status;
  final String? conversationId;
  final String? currentMessageId;
  final StringBuffer buffer;
  final List<StreamCitation> citations;
  final String? errorMessage;
  final int latencyMs;

  const ChatStreamingState({
    required this.status,
    this.conversationId,
    this.currentMessageId,
    required this.buffer,
    required this.citations,
    this.errorMessage,
    this.latencyMs = 0,
  });

  String get accumulatedText => buffer.toString();
  bool get isBusy =>
      status == StreamStatus.connecting || status == StreamStatus.streaming;

  factory ChatStreamingState.initial() => ChatStreamingState(
        status: StreamStatus.idle,
        buffer: StringBuffer(),
        citations: const [],
      );

  ChatStreamingState copyWith({
    StreamStatus? status,
    String? conversationId,
    String? currentMessageId,
    StringBuffer? buffer,
    List<StreamCitation>? citations,
    String? errorMessage,
    int? latencyMs,
  }) {
    return ChatStreamingState(
      status: status ?? this.status,
      conversationId: conversationId ?? this.conversationId,
      currentMessageId: currentMessageId ?? this.currentMessageId,
      buffer: buffer ?? this.buffer,
      citations: citations ?? this.citations,
      errorMessage: errorMessage ?? this.errorMessage,
      latencyMs: latencyMs ?? this.latencyMs,
    );
  }
}

// -----------------------------------------------------------------------------
// 3. CLIENT TECHNIQUE HTTP SSE VERS LA SUPABASE EDGE FUNCTION `chat`
// -----------------------------------------------------------------------------

class SseChatClient {
  final SupabaseClient _supabase;
  final http.Client _httpClient;

  SseChatClient({
    SupabaseClient? supabaseOverride,
    http.Client? httpClient,
  })  : _supabase = supabaseOverride ?? supabase,
        _httpClient = httpClient ?? http.Client();

  /// Envoie un prompt clinique à l'Edge Function `chat` et retourne un
  /// flux d'événements typés (init -> delta* -> done | error).
  Stream<ChatStreamEvent> streamClinicalChat({
    required String message,
    String? conversationId,
    String sourcesMode = 'all', // 'all', 'library_only', 'web_only'
    String searchMode = 'deep', // 'quick' (1 recherche) ou 'deep' (plusieurs, façon Perplexity)
    String? documentId,
    String? folderId,
  }) async* {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      yield const ChatErrorEvent('Session expirée. Reconnectez-vous.');
      return;
    }

    final jwt = session.accessToken;
    final edgeFunctionUrl = '${_supabase.functionsUrl}/chat';

    final requestBody = jsonEncode({
      'message': message,
      if (conversationId != null) 'conversationId': conversationId,
      'sourcesMode': sourcesMode,
      'searchMode': searchMode,
      if (documentId != null) 'documentId': documentId,
      if (folderId != null) 'folderId': folderId,
      'clientTimestamp': DateTime.now().toIso8601String(),
    });

    final request = http.Request('POST', Uri.parse(edgeFunctionUrl));
    request.headers.addAll({
      HttpHeaders.authorizationHeader: 'Bearer $jwt',
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'text/event-stream',
      'apikey': _supabase.supabaseKey,
    });
    request.body = requestBody;

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _httpClient.send(request);
    } catch (netErr) {
      yield ChatErrorEvent("Échec de connexion au serveur clinique : $netErr");
      return;
    }

    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream.bytesToString();
      yield ChatErrorEvent(
        'Erreur Edge Function (${streamedResponse.statusCode}) : $errorBody',
      );
      return;
    }

    String currentEvent = 'message';
    const lineSplitter = LineSplitter();

    try {
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        final lines = lineSplitter.convert(chunk);

        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (line.isEmpty) continue;

          if (line.startsWith('event: ')) {
            currentEvent = line.substring(7).trim();
            continue;
          }

          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6).trim();
            if (dataStr == '[DONE]') continue;

            try {
              final Map<String, dynamic> data = jsonDecode(dataStr);

              switch (currentEvent) {
                case 'init':
                  final citationsJson = data['citations'] as List<dynamic>? ?? [];
                  final parsedCitations = citationsJson
                      .map((c) => StreamCitation.fromJson(c as Map<String, dynamic>))
                      .toList();

                  yield ChatInitEvent(
                    conversationId: data['conversationId'] as String? ?? '',
                    messageId: data['messageId'] as String? ?? '',
                    citations: parsedCitations,
                    sourcesCount: data['sourcesCount'] as int? ?? parsedCitations.length,
                  );
                  break;

                case 'delta':
                  yield ChatDeltaEvent(data['text'] as String? ?? '');
                  break;

                case 'done':
                  final citationsJson = data['citations'] as List<dynamic>? ?? [];
                  final parsedCitations = citationsJson
                      .map((c) => StreamCitation.fromJson(c as Map<String, dynamic>))
                      .toList();

                  yield ChatDoneEvent(
                    conversationId: data['conversationId'] as String? ?? '',
                    messageId: data['messageId'] as String? ?? '',
                    totalLength: data['totalLength'] as int? ?? 0,
                    latencyMs: data['latencyMs'] as int? ?? 0,
                    citations: parsedCitations,
                  );
                  break;

                case 'error':
                  yield ChatErrorEvent(data['error'] as String? ?? 'Erreur inconnue de streaming');
                  break;

                default:
                  if (data.containsKey('text')) {
                    yield ChatDeltaEvent(data['text'] as String);
                  }
                  break;
              }
            } catch (jsonErr) {
              debugPrint('Fragment non JSON dans SSE : $dataStr');
            }
          }
        }
      }
    } catch (streamException) {
      yield ChatErrorEvent('Interruption anormale du flux SSE : $streamException');
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

// -----------------------------------------------------------------------------
// 4. PROVIDERS RIVERPOD
// -----------------------------------------------------------------------------

final sseChatClientProvider = Provider<SseChatClient>((ref) {
  final client = SseChatClient();
  ref.onDispose(client.dispose);
  return client;
});

class ChatStreamNotifier extends StateNotifier<ChatStreamingState> {
  final SseChatClient _sseClient;
  StreamSubscription<ChatStreamEvent>? _subscription;

  ChatStreamNotifier(this._sseClient) : super(ChatStreamingState.initial());

  Future<void> sendClinicalQuery({
    required String query,
    String? conversationId,
    String sourcesMode = 'all',
    String searchMode = 'deep',
    String? documentId,
    VoidCallback? onTokenReceived,
    VoidCallback? onCompleted,
  }) async {
    await cancelStream();

    final buffer = StringBuffer();
    state = state.copyWith(
      status: StreamStatus.connecting,
      buffer: buffer,
      citations: [],
      errorMessage: null,
      conversationId: conversationId,
    );

    _subscription = _sseClient
        .streamClinicalChat(
          message: query,
          conversationId: conversationId,
          sourcesMode: sourcesMode,
          searchMode: searchMode,
          documentId: documentId,
        )
        .listen(
          (event) {
            if (event is ChatInitEvent) {
              state = state.copyWith(
                status: StreamStatus.streaming,
                conversationId: event.conversationId,
                currentMessageId: event.messageId,
                citations: event.citations,
              );
            } else if (event is ChatDeltaEvent) {
              buffer.write(event.deltaText);
              state = state.copyWith(status: StreamStatus.streaming, buffer: buffer);
              onTokenReceived?.call();
            } else if (event is ChatDoneEvent) {
              state = state.copyWith(
                status: StreamStatus.completed,
                latencyMs: event.latencyMs,
                citations: event.citations.isNotEmpty ? event.citations : state.citations,
              );
              onCompleted?.call();
            } else if (event is ChatErrorEvent) {
              state = state.copyWith(status: StreamStatus.error, errorMessage: event.error);
            }
          },
          onError: (err) {
            state = state.copyWith(
              status: StreamStatus.error,
              errorMessage: 'Erreur réseau critique : $err',
            );
          },
          cancelOnError: true,
        );
  }

  Future<void> cancelStream() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }
    if (state.isBusy) {
      state = state.copyWith(status: StreamStatus.idle);
    }
  }

  void resetState() {
    cancelStream();
    state = ChatStreamingState.initial();
  }

  @override
  void dispose() {
    cancelStream();
    super.dispose();
  }
}

final chatStreamNotifierProvider =
    StateNotifierProvider<ChatStreamNotifier, ChatStreamingState>((ref) {
  final sseClient = ref.watch(sseChatClientProvider);
  return ChatStreamNotifier(sseClient);
});
