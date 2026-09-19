// =============================================================================
// DRUGS IA - PROVIDER DE SESSION VOCALE
// Boucle complète : micro (speech_to_text, natif) -> pipeline chat existant
// (sse_chat_client.dart) -> synthèse vocale (flutter_tts, natif).
//
// Choix d'architecture : la reconnaissance et la synthèse utilisent les
// moteurs natifs du téléphone (rapides, hors-ligne, support du français),
// plutôt que l'Edge Function `stt` (Groq Whisper) écrite par ailleurs.
// Cette dernière reste disponible côté serveur pour un usage futur (ex.
// transcription de fichiers audio importés) mais n'est pas sur ce chemin.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/network/sse_chat_client.dart';

enum VoiceSessionState { listening, thinking, speaking, muted }

class VoiceSessionUiState {
  final VoiceSessionState sessionState;
  final String liveTranscript;
  final String assistantText;
  final String? errorMessage;

  const VoiceSessionUiState({
    required this.sessionState,
    this.liveTranscript = '',
    this.assistantText = '',
    this.errorMessage,
  });

  VoiceSessionUiState copyWith({
    VoiceSessionState? sessionState,
    String? liveTranscript,
    String? assistantText,
    String? errorMessage,
  }) {
    return VoiceSessionUiState(
      sessionState: sessionState ?? this.sessionState,
      liveTranscript: liveTranscript ?? this.liveTranscript,
      assistantText: assistantText ?? this.assistantText,
      errorMessage: errorMessage,
    );
  }
}

/// Retire la mise en forme Markdown et les pastilles de citation `[1]`
/// pour obtenir un texte naturel à l'oral.
String stripForSpeech(String text) {
  return text
      .replaceAll(RegExp(r'\[\d+\]'), '')
      .replaceAll(RegExp(r'\*\*|__|`'), '')
      .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^[-•]\s*', multiLine: true), '')
      .replaceAll(RegExp(r'\n{2,}'), '. ')
      .trim();
}

class VoiceSessionNotifier extends StateNotifier<VoiceSessionUiState> {
  final Ref _ref;
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _speechAvailable = false;
  bool _sessionEnded = false;

  VoiceSessionNotifier(this._ref)
      : super(const VoiceSessionUiState(sessionState: VoiceSessionState.listening)) {
    _configureTts();
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.48);
    await _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(() {
      if (!_sessionEnded && state.sessionState != VoiceSessionState.muted) {
        _startListening();
      }
    });
  }

  Future<void> start() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      state = state.copyWith(
        sessionState: VoiceSessionState.muted,
        errorMessage: "Accès au microphone refusé. Activez-le dans les réglages du téléphone.",
      );
      return;
    }

    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        // Le moteur natif s'arrête tout seul après un court silence (timeout
        // système, souvent 2-5s selon le téléphone), sans forcément avoir
        // produit de résultat final. Si on est toujours censé écouter (aucune
        // bascule vers réflexion/parole/muet entre-temps), on relance
        // immédiatement l'écoute pour ne pas laisser le micro mort.
        if ((status == 'notListening' || status == 'done') &&
            !_sessionEnded &&
            state.sessionState == VoiceSessionState.listening) {
          _startListening();
        }
      },
      onError: (err) {
        state = state.copyWith(errorMessage: 'Erreur reconnaissance vocale : ${err.errorMsg}');
        // La plupart des erreurs natives (pas de correspondance, timeout de
        // silence, micro momentanément occupé) ne sont pas fatales : on
        // relance l'écoute au lieu de laisser la session bloquée en silence.
        if (!err.permanent && !_sessionEnded && state.sessionState == VoiceSessionState.listening) {
          _startListening();
        }
      },
    );

    if (!_speechAvailable) {
      state = state.copyWith(
        sessionState: VoiceSessionState.muted,
        errorMessage: "Reconnaissance vocale indisponible sur cet appareil.",
      );
      return;
    }

    await _startListening();
  }

  Future<void> _startListening() async {
    if (_sessionEnded || state.sessionState == VoiceSessionState.muted) return;

    state = state.copyWith(sessionState: VoiceSessionState.listening, liveTranscript: '');
    await _speech.listen(
      onResult: (result) {
        state = state.copyWith(liveTranscript: result.recognizedWords);
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _handleUserUtterance(result.recognizedWords.trim());
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: 'fr_FR',
        // Tolère les hésitations naturelles d'une question clinique (le
        // timeout de silence par défaut du moteur natif est souvent trop
        // court, 2-5s selon l'appareil) sans laisser une session muette
        // indéfiniment si l'utilisateur ne parle finalement pas.
        pauseFor: const Duration(seconds: 6),
        listenFor: const Duration(seconds: 45),
      ),
    );
  }

  Future<void> _handleUserUtterance(String query) async {
    await _speech.stop();
    state = state.copyWith(sessionState: VoiceSessionState.thinking);

    try {
      await _ref.read(chatStreamNotifierProvider.notifier).sendClinicalQuery(
            query: query,
            sourcesMode: 'all',
            onCompleted: () async {
              final responseText = _ref.read(chatStreamNotifierProvider).accumulatedText;
              await _speak(responseText);
            },
            // La requête part en tâche de fond (le flux SSE est piloté par
            // événements) : sans ce relais, une erreur serveur ou un
            // timeout laissait la session bloquée en "réflexion" pour
            // toujours, car seul `onCompleted` déclenchait la suite.
            onError: (message) async {
              if (_sessionEnded) return;
              state = state.copyWith(errorMessage: message);
              await _speak("Désolé, je n'ai pas pu obtenir de réponse. Vous pouvez reposer votre question.");
            },
          );
    } catch (err) {
      state = state.copyWith(errorMessage: 'Échec de la requête : $err');
      if (!_sessionEnded) await _startListening();
    }
  }

  Future<void> _speak(String responseText) async {
    if (_sessionEnded) return;
    final spoken = stripForSpeech(responseText);
    state = state.copyWith(sessionState: VoiceSessionState.speaking, assistantText: spoken);
    if (spoken.isEmpty) {
      await _startListening();
      return;
    }
    await _tts.speak(spoken);
    // La reprise de l'écoute se fait dans le completion handler du TTS.
  }

  /// Coupe la parole en cours (barge-in) et reprend l'écoute immédiatement.
  Future<void> interrupt() async {
    if (state.sessionState != VoiceSessionState.speaking) return;
    await _tts.stop();
    await _startListening();
  }

  Future<void> toggleMute() async {
    if (state.sessionState == VoiceSessionState.muted) {
      state = state.copyWith(sessionState: VoiceSessionState.listening, errorMessage: null);
      await _startListening();
    } else {
      await _speech.stop();
      await _tts.stop();
      state = state.copyWith(sessionState: VoiceSessionState.muted);
    }
  }

  Future<void> stopSession() async {
    _sessionEnded = true;
    await _speech.stop();
    await _tts.stop();
  }

  @override
  void dispose() {
    _sessionEnded = true;
    _speech.cancel();
    _tts.stop();
    super.dispose();
  }
}

final voiceSessionProvider =
    StateNotifierProvider.autoDispose<VoiceSessionNotifier, VoiceSessionUiState>((ref) {
  final notifier = VoiceSessionNotifier(ref);
  ref.onDispose(notifier.stopSession);
  return notifier;
});
