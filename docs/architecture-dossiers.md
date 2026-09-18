# =============================================================================
# DRUGS IA CLINICAL INTELLIGENCE 2026 - ARCHITECTURE DES DOSSIERS FLUTTER
# Structure type Clean Architecture / Feature-First
# =============================================================================

drugs_ia_app/
│
├── pubspec.yaml                          # Dépendances (Supabase, Riverpod, SQLCipher, etc.)
├── README.md                             # Guide d'installation et déploiement
│
├── assets/
│   ├── fonts/                            # Plus Jakarta Sans (Regular, Medium, SemiBold, Bold)
│   ├── icons/                            # Badges RAG, icônes PDF/DOCX, symboles toxicologie
│   └── images/                           # Orbes sensoriels et illustrations onboarding
│
└── lib/
    ├── main.dart                         # Point d'entrée de l'application (initialisation Supabase)
    │
    ├── core/                             # Socle transversal indépendant des fonctionnalités
    │   ├── theme/
    │   │   ├── app_theme.dart            # Palette "Serene Clinical", Typography, ThemeData (Module 01)
    │   │   └── app_colors.dart           # Tokens chromatiques précis (ardoise, vert d'eau, bleu pastel)
    │   ├── network/
    │   │   ├── supabase_client.dart      # Singleton Supabase + intercepteur de jetons HDS
    │   │   └── sse_chat_client.dart      # Client SSE pour le streaming token par token avec Claude
    │   ├── security/
    │   │   ├── encrypted_cache.dart      # Gestionnaire du cache local SQLite chiffré en AES-256
    │   │   └── biometric_auth.dart       # Verrouillage par FaceID / Empreinte digitale
    │   └── utils/
    │       ├── date_formatter.dart       # Formatage médical français strict
    │       └── dose_calculator.dart      # Outils d'aide au calcul de charge (ex: NAC sur poids)
    │
    ├── shared_widgets/                   # Composants réutilisables sur plusieurs écrans
    │   ├── floating_capsule_nav.dart     # Barre de navigation flottante en verre dépoli (Module 01)
    │   ├── citation_badge.dart           # Badge numéroté cliquable [1] (Module 01)
    │   └── hds_security_pill.dart        # Badge de réassurance HDS & RLS
    │
    └── features/                         # Modules fonctionnels découpés par domaine métier
        │
        ├── auth/                         # Module 08 : Onboarding & Espace Praticien
        │   ├── screens/
        │   │   └── onboarding_screen.dart # Carrousel 3 étapes (Mission, Disclaimer, Auth)
        │   └── providers/
        │       └── auth_provider.dart    # Gestion de session Supabase & consentement déontologique
        │
        ├── chat/                         # Module 02 & Module 05 & Module 11 : Conversation Clinique
        │   ├── screens/
        │   │   ├── chat_screen.dart      # Écran principal avec streaming et sélecteur de sources
        │   │   └── sidebar_screen.dart   # Tiroir d'historique groupé (Aujourd'hui / 7j / Plus ancien)
        │   ├── widgets/
        │   │   ├── sources_bottom_sheet.dart # Inspection détaillée des citations RAG/Web (Module 11)
        │   │   ├── source_filter_bar.dart    # Pills de filtrage (Toutes, Bibliothèque, Web)
        │   │   └── medical_disclaimer_box.dart # Encart éducatif de précaution sous réponses
        │   └── providers/
        │       └── chat_provider.dart    # StateNotifier de la conversation active
        │
        ├── library/                      # Module 03 & Module 04 : Bibliothèque RAG Personnelle
        │   ├── screens/
        │   │   ├── library_screen.dart   # Liste des PDF/protocoles, jauge 50 Mo pgvector
        │   │   └── document_detail_screen.dart # Détail du PDF, métadonnées et chunks HNSW
        │   ├── widgets/
        │   │   ├── document_upload_sheet.dart # Bottom sheet d'importation de documents
        │   │   └── chunk_card.dart       # Affichage individuel d'un segment avec similarité cosinus
        │   └── providers/
        │       └── library_provider.dart # Récupération des documents et statut d'ingestion
        │
        ├── voice/                        # Module 06 : Discussion Vocale Mains-Libres
        │   ├── screens/
        │   │   └── voice_screen.dart     # Plein écran avec Orbe sensoriel animé 2026
        │   └── widgets/
        │       └── sensory_orb_painter.dart # CustomPainter animé réactif à l'audio et au statut
        │
        ├── settings/                     # Module 07 : Réglages Cliniques & Conformité
        │   ├── screens/
        │   │   └── settings_screen.dart  # Profil Dr. Marceau, switches F2, quotas et purge
        │   └── providers/
        │       └── settings_provider.dart # Synchronisation des préférences dans profiles.preferences
        │
        ├── resilience/                   # Module 10 : États Vides & Mode Hors-ligne
        │   ├── screens/
        │   │   └── empty_states_screen.dart # Déconnexion réseau, bascule cache dégradé et erreurs
        │   └── services/
        │       └── connectivity_service.dart # Détection en temps réel du statut réseau
        │
        └── mcp/                          # Module 09 : Connecteurs MCP (Phase 2)
            ├── screens/
            │   └── mcp_connectors_screen.dart # Gestion des serveurs distants, latence et clés API
            └── models/
                └── mcp_server_model.dart # Modèle de données d'un serveur MCP
