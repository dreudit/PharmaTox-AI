import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Détection en temps réel du statut réseau, utilisée pour basculer
/// l'interface en mode dégradé (lecture des documents et de l'historique
/// déjà mis en cache, file d'attente des questions non envoyées).
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityStreamProvider);
  return connectivity.maybeWhen(
    data: (results) => !results.contains(ConnectivityResult.none) && results.isNotEmpty,
    orElse: () => true,
  );
});
