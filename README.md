# Drugs IA

Application mobile d'assistant IA spécialisé en **pharmacologie et toxicologie** :
conversation textuelle et vocale, bibliothèque de documents personnels interrogeable
(RAG), recherche web sourcée, le tout avec des réponses toujours citées.

Voir le cahier des charges complet dans [`docs/cahier-des-charges.md`](docs/cahier-des-charges.md)
et les spécifications UI/UX dans [`docs/specifications-ui-ux.md`](docs/specifications-ui-ux.md).

## État du projet

- ✅ 12 écrans Flutter (`lib/features/**`) : onboarding, connexion, chat streaming,
  bibliothèque, détail document, sidebar/historique, discussion vocale, réglages,
  connecteurs MCP, états vides/résilience, panneau des sources.
- ✅ Design system "Serene Clinical Intelligence" (`lib/core/theme`).
- ✅ Client SSE Riverpod pour le streaming du chat (`lib/core/network/sse_chat_client.dart`).
- ✅ Schéma SQL Supabase complet avec RLS, pgvector/HNSW, bucket Storage privé
  (`supabase/migrations/20250101000000_init_schema.sql`).
- ✅ Squelettes des Edge Functions `chat`, `search-library`, `ingest-document`
  (`supabase/functions/**`).
- ⏳ À compléter une fois le projet Supabase branché : extraction réelle de texte
  PDF/DOCX dans `ingest-document`, calcul d'embeddings, recherche web sourcée
  (`web-search`), voix (STT/TTS), connecteurs MCP (`mcp-proxy`), quotas (`usage-guard`).

## Démarrer le projet Flutter

Les dossiers de plateforme (`android/`, `ios/`, `web/`...) ne sont pas versionnés :
générez-les localement, une seule fois, à la racine du dépôt :

```bash
flutter create . --org com.drugsia.app --project-name drugs_ia_app
flutter pub get
```

Puis lancez l'app en fournissant l'URL et la clé anonyme de votre projet Supabase
(l'app affiche un écran de configuration requise si elles sont absentes) :

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

## Configurer le backend Supabase

1. Créez un projet Supabase (région Europe recommandée pour la conformité RGPD).
2. Appliquez la migration :
   ```bash
   supabase link --project-ref <votre-ref>
   supabase db push
   ```
   (ou copiez le contenu de `supabase/migrations/20250101000000_init_schema.sql`
   dans l'éditeur SQL du dashboard Supabase).
3. Renseignez les secrets des Edge Functions :
   ```bash
   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
   ```
4. Déployez les fonctions :
   ```bash
   supabase functions deploy chat
   supabase functions deploy search-library
   supabase functions deploy ingest-document
   ```
5. Activez les providers d'authentification souhaités (Email, Google) dans
   Auth > Providers du dashboard.

## Architecture

```
lib/
├── main.dart                 # Point d'entrée, routes, initialisation Supabase
├── core/
│   ├── theme/                 # Design system (couleurs, typographie, ThemeData)
│   └── network/                # Client Supabase, config d'environnement, client SSE
├── shared_widgets/            # Nav flottante, badges de citation
└── features/
    ├── auth/                  # Onboarding, décharge, connexion
    ├── chat/                  # Chat principal, sidebar/historique, sources
    ├── library/                # Bibliothèque de documents, détail & segments
    ├── voice/                  # Discussion vocale plein écran
    ├── settings/                # Réglages & préférences
    ├── mcp/                     # Connecteurs MCP (phase 2)
    └── resilience/              # États vides, hors-ligne, erreurs

supabase/
├── config.toml
├── migrations/                 # Schéma SQL (tables, RLS, pgvector)
└── functions/                  # Edge Functions (chat, search-library, ingest-document)
```

Le détail des dossiers est décrit dans [`docs/architecture-dossiers.md`](docs/architecture-dossiers.md).

## Avertissement

Drugs IA est un outil éducatif et documentaire d'aide à l'information. Il ne
constitue pas un dispositif médical et ne remplace ni un avis médical, ni les
recommandations d'un centre antipoison en situation d'urgence.
