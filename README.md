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
- ✅ Squelettes des Edge Functions `chat`, `search-library`, `ingest-document`,
  `stt` (Groq Whisper) (`supabase/functions/**`).
- ✅ Projet Supabase branché par défaut (`pqwdmxuppitudhjgnxnv`), migration et
  secrets à appliquer manuellement (voir plus bas — bloqué par le réseau de
  cette sandbox, pas par le code).
- ✅ Pipeline vocal complet (micro natif → chat → synthèse vocale native),
  boucle continue et interruption (`lib/features/voice/providers/voice_session_provider.dart`).
- ⏳ À compléter : extraction réelle de texte PDF/DOCX dans `ingest-document`,
  calcul d'embeddings, recherche web sourcée (`web-search`), connecteurs
  MCP (`mcp-proxy`), quotas (`usage-guard`).

## Démarrer le projet Flutter

Le projet Supabase est déjà branché par défaut (`lib/core/network/app_config.dart`) :
URL et clé publiable (`sb_publishable_...`, sans danger côté client — la
sécurité vient des policies RLS, pas du secret de cette clé). Les dossiers de
plateforme (`android/`, `ios/`, `web/`...) ne sont pas versionnés : générez-les
localement, une seule fois, à la racine du dépôt :

```bash
flutter create . --org com.drugsia.app --project-name drugs_ia_app
flutter pub get
flutter run
```

Pour pointer vers un autre projet Supabase (dev personnel) :

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
```

## Configurer le backend Supabase

> ⚠️ Cet environnement Claude Code n'a pas accès réseau à `*.supabase.co`
> (politique d'egress de la sandbox) : le CLI Supabase y est installé mais ne
> peut pas atteindre l'API de gestion. Les étapes ci-dessous doivent donc être
> exécutées **depuis votre propre machine** (ou tout environnement sans cette
> restriction), avec le jeton d'accès personnel Supabase que vous avez fourni.

1. Lier le projet (déjà créé : `pqwdmxuppitudhjgnxnv`) :
   ```bash
   supabase login   # ou : export SUPABASE_ACCESS_TOKEN=sbp_...
   supabase link --project-ref pqwdmxuppitudhjgnxnv
   ```
2. Appliquer la migration :
   ```bash
   supabase db push
   ```
   (ou copiez le contenu de `supabase/migrations/20250101000000_init_schema.sql`
   dans l'éditeur SQL du dashboard Supabase — Project > SQL Editor — si vous
   préférez ne pas installer le CLI).
3. Renseigner les secrets des Edge Functions (Dashboard > Edge Functions >
   Secrets, ou en CLI) :
   ```bash
   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
   supabase secrets set GROQ_API_KEY=gsk_...   # utilisé par la fonction `stt`
   ```
4. Déployer les fonctions :
   ```bash
   supabase functions deploy chat
   supabase functions deploy search-library
   supabase functions deploy ingest-document
   supabase functions deploy stt
   ```
5. Activer les providers d'authentification souhaités (Email, Google) dans
   Auth > Providers du dashboard.

Aucune de ces clés (`ANTHROPIC_API_KEY`, `GROQ_API_KEY`, le jeton d'accès
`sbp_...`) ne doit jamais être commitée dans ce dépôt : elles vivent
uniquement dans les secrets Supabase, jamais dans le code Flutter ni dans
`supabase/config.toml`.

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
