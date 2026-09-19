// =============================================================================
// DRUGS IA - DISCUSSION VOCALE PLEIN ÉCRAN & ORBE SENSORIEL (Écran 6)
// Boucle réelle micro -> chat -> synthèse vocale, via voice_session_provider.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/voice_session_provider.dart';

/// Écran de discussion vocale plein écran avec orbe sensoriel animé.
class VoiceScreen extends ConsumerStatefulWidget {
  final VoidCallback? onCloseRequested;

  const VoiceScreen({super.key, this.onCloseRequested});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen> with TickerProviderStateMixin {
  bool _isLiveTranscriptExpanded = true;

  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceSessionProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _closeScreen() {
    HapticFeedback.heavyImpact();
    ref.read(voiceSessionProvider.notifier).stopSession();
    if (widget.onCloseRequested != null) {
      widget.onCloseRequested!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(voiceSessionProvider);

    ref.listen(voiceSessionProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(next.errorMessage!)),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopVoiceHeader(uiState),
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildAmbientBacklight(uiState.sessionState),
                    AnimatedBuilder(
                      animation: Listenable.merge([_pulseController, _rotationController, _waveController]),
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(260, 260),
                          painter: _SensoryOrbPainter(
                            state: uiState.sessionState,
                            pulseProgress: _pulseController.value,
                            rotationAngle: _rotationController.value * 2 * math.pi,
                            waveProgress: _waveController.value,
                          ),
                        );
                      },
                    ),
                    Positioned(bottom: 24, child: _buildVoiceStatusBadge(uiState.sessionState)),
                  ],
                ),
              ),
            ),
            _buildLiveTranscriptSheet(uiState),
            _buildBottomControlsBar(uiState.sessionState),
          ],
        ),
      ),
    );
  }

  Widget _buildTopVoiceHeader(VoiceSessionUiState uiState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: uiState.sessionState == VoiceSessionState.muted ? AppColors.errorRed : AppColors.accentTeal, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('Mode vocal', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondaryText, letterSpacing: -0.01)),
          ]),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.primaryText, size: 22),
            onPressed: _closeScreen,
            tooltip: 'Quitter',
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientBacklight(VoiceSessionState currentState) {
    final Color baseColor = switch (currentState) {
      VoiceSessionState.listening => AppColors.accentTeal.withOpacity(0.12),
      VoiceSessionState.thinking => const Color(0xFF6366F1).withOpacity(0.14),
      VoiceSessionState.speaking => AppColors.accentBlue.withOpacity(0.12),
      VoiceSessionState.muted => AppColors.errorRed.withOpacity(0.08),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      width: 320,
      height: 320,
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: baseColor, blurRadius: 90, spreadRadius: 30)]),
    );
  }

  Widget _buildVoiceStatusBadge(VoiceSessionState currentState) {
    final (String label, IconData icon, Color iconColor) = switch (currentState) {
      VoiceSessionState.listening => ('Écoute active...', Icons.mic_rounded, AppColors.accentTeal),
      VoiceSessionState.thinking => ('Recherche et raisonnement...', Icons.bubble_chart_rounded, const Color(0xFF6366F1)),
      VoiceSessionState.speaking => ('Réponse en cours (touchez pour interrompre)', Icons.volume_up_rounded, AppColors.accentBlue),
      VoiceSessionState.muted => ('Microphone en pause', Icons.mic_off_rounded, AppColors.errorRed),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withOpacity(0.85),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.8)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
      ]),
    );
  }

  Widget _buildLiveTranscriptSheet(VoiceSessionUiState uiState) {
    final hasContent = uiState.liveTranscript.isNotEmpty || uiState.assistantText.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.surfaceContainerHigh.withOpacity(0.7))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: const [
                Icon(Icons.notes_rounded, size: 15, color: AppColors.secondaryText),
                SizedBox(width: 6),
                Text('Transcription en direct', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.secondaryText, letterSpacing: 0.2)),
              ]),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isLiveTranscriptExpanded = !_isLiveTranscriptExpanded);
                },
                child: Icon(_isLiveTranscriptExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded, size: 20, color: AppColors.secondaryText),
              ),
            ],
          ),
          if (_isLiveTranscriptExpanded) ...[
            const SizedBox(height: 10),
            if (!hasContent)
              const Text('Parlez pour commencer...', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, color: AppColors.tertiaryText, fontStyle: FontStyle.italic))
            else ...[
              if (uiState.liveTranscript.isNotEmpty)
                Text('« ${uiState.liveTranscript} »', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.secondaryText, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (uiState.assistantText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(uiState.assistantText, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.primaryText, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBottomControlsBar(VoiceSessionState currentState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: currentState == VoiceSessionState.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: currentState == VoiceSessionState.muted ? 'Réactiver' : 'Muet',
            isActive: currentState == VoiceSessionState.muted,
            activeColor: AppColors.errorRed,
            onTap: () {
              HapticFeedback.mediumImpact();
              ref.read(voiceSessionProvider.notifier).toggleMute();
            },
          ),
          _buildActionButton(
            icon: Icons.pause_circle_outline_rounded,
            label: 'Interrompre',
            isActive: currentState == VoiceSessionState.speaking,
            activeColor: AppColors.accentBlue,
            onTap: () {
              HapticFeedback.mediumImpact();
              ref.read(voiceSessionProvider.notifier).interrupt();
            },
          ),
          _buildActionButton(
            icon: Icons.call_end_rounded,
            label: 'Terminer',
            isActive: true,
            activeColor: AppColors.primaryText,
            onTap: _closeScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isActive ? activeColor : AppColors.surfaceContainerLowest,
              shape: BoxShape.circle,
              border: Border.all(color: isActive ? activeColor : AppColors.surfaceContainerHigh.withOpacity(0.8)),
            ),
            child: Icon(icon, color: isActive ? Colors.white : AppColors.primaryText, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
        ],
      ),
    );
  }
}

/// Peintre personnalisé de l'orbe sensoriel, réactif à l'état vocal.
class _SensoryOrbPainter extends CustomPainter {
  final VoiceSessionState state;
  final double pulseProgress;
  final double rotationAngle;
  final double waveProgress;

  _SensoryOrbPainter({
    required this.state,
    required this.pulseProgress,
    required this.rotationAngle,
    required this.waveProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (size.width / 2) * (0.82 + (pulseProgress * 0.08));

    final List<Color> gradientColors = switch (state) {
      VoiceSessionState.listening => const [Color(0xFF7C3AED), Color(0xFF9333EA), Color(0xFFC026D3), Color(0xFFEDE4FC)],
      VoiceSessionState.thinking => const [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEEF2FF)],
      VoiceSessionState.speaking => const [Color(0xFFC026D3), Color(0xFFD946EF), Color(0xFF9333EA), Color(0xFFFAE4F8)],
      VoiceSessionState.muted => const [Color(0xFF94A3B8), Color(0xFFCBD5E1), Color(0xFFF1F5F9)],
    };

    final outerRingPaint = Paint()
      ..color = gradientColors.first.withOpacity(0.15 + (waveProgress * 0.12))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 + (waveProgress * 4.0);
    canvas.drawCircle(center, baseRadius + 14 * waveProgress, outerRingPaint);

    final gradient = SweepGradient(
      center: Alignment.center,
      startAngle: 0.0,
      endAngle: math.pi * 2,
      transform: GradientRotation(rotationAngle),
      colors: gradientColors,
    );

    final rect = Rect.fromCircle(center: center, radius: baseRadius);
    final orbPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius, orbPaint);

    final innerHighlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.3),
        radius: 0.85,
        colors: [Colors.white.withOpacity(0.55), Colors.white.withOpacity(0.0)],
      ).createShader(rect);
    canvas.drawCircle(center, baseRadius, innerHighlightPaint);
  }

  @override
  bool shouldRepaint(covariant _SensoryOrbPainter oldDelegate) {
    return oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.waveProgress != waveProgress ||
        oldDelegate.state != state;
  }
}
