# Spécifications Techniques & UI/UX Drugs IA (Refonte 2026)
**Document de Référence pour l'Implémentation Mobile (Flutter / Supabase / Claude API)**

---

## 1. Synthèse du Design System 2026 (« Serene Clinical Intelligence »)

Inspiré de l'épure de **Claude AI Mobile** et de la sérénité thérapeutique de **Vera Health App**, ce design system privilégie les surfaces minérales soyeuses, l'absence de bordures dures et d'ombres projetées lourdes, et la respiration typographique.

### 1.1 Palette Chromatique

| Token Figma / Flutter | Hex Code | Usage & Rôle |
|---|---|---|
| `surfaceBackground` | `#F8FAFA` | Fond principal minéral, reposant pour les yeux en garde hospitalière |
| `surfaceContainerLowest` | `#FFFFFF` | Fond des cartes interactives et panneaux de contenu |
| `surfaceContainerLow` | `#F2F4F4` | Zones d'entrée (inputs, pills inactives, barres de recherche) |
| `surfaceContainerHigh` | `#E4E7E7` | Séparateurs ultra-doux, bordures transparentes (10-15% opacité) |
| `primaryText` / `primary` | `#1E2A38` | Bleu-nuit ardoise profond, typographie principale, boutons d'action clés |
| `secondaryText` | `#536371` | Gris-ardoise clinique, descriptions, métadonnées secondaires |
| `accentTeal` | `#0D9488` / `#2DD4BF` | Pastilles de validation RAG, statut d'indexation optimal, indicateurs de santé |
| `accentBlueSoft` | `#E0F2FE` / `#0284C7` | Pills de filtrage actives, surlignage d'extraits cités `[1]`, badges d'outils |
| `warningAmber` | `#F59E0B` / `#FEF3C7` | Indicateurs de mode dégradé, quotas partiels, alertes pharmacovigilance |
| `glassNavbarBg` | `rgba(255, 255, 255, 0.75)` | Barre de navigation flottante avec flou d'arrière-plan (`backdrop-filter: blur(20px)`) |

### 1.2 Typographie & Rythme (Plus Jakarta Sans)
- **Headlines (`headline-sm`, `headline-md`)** : `Plus Jakarta Sans`, 20px à 24px, Semi-Bold / Bold, letter-spacing `-0.02em`.
- **Corps de texte (`body-md`)** : 15px / 16px, Regular / Medium, line-height `1.55` pour une lisibilité médicale optimale sans fatigue visuelle.
- **Labels & Micro-copies (`label-sm`, `label-xs`)** : 11px à 13px, Medium, letter-spacing `0.01em`, utilisé pour les métadonnées (tokens, latence, statut HDS).

### 1.3 Composants Réutilisables Clés
1. **Floating Capsule Navigation Bar** :
   - Position : Fixe en bas (`bottom: 24px`), centrée horizontalement.
   - Forme : `border-radius: 9999px` (pill), padding `8px 16px`.
   - Matériau : Verre dépoli translucide avec micro-bordure `rgba(30, 42, 56, 0.08)`.
   - Items : 3 icônes (Chat, Bibliothèque, Profil/Réglages).
2. **Citations RAG / Web Cards** :
   - Style : Pas de contour noir. Fond blanc pur sur surface minérale, micro-pastille numérotée `[1]` cerclée en bleu pastel.
   - Interaction : Clic ouvre la **Bottom Sheet** détaillée ou prévisualise le PDF.
3. **Pills de filtrage** :
   - Hauteur 34px, coins arrondis complets (`rounded-full`), transition fluide d'état actif (`#1E2A38` ou `#E0F2FE`) vers inactif (`#F2F4F4`).

---

## 2. Cartographie des Écrans & Logique Fonctionnelle

| ID Écran | Nom de l'Écran | Rôle & Composants Clés | Événements & State Management |
|---|---|---|---|
| **E1** | *Onboarding 1 - Mission* | Présentation de la valeur (RAG + Web + Voix), composition circulaire sensorielle | Transition `onNextPressed` vers E2, bypass si déjà vu |
| **E2** | *Onboarding 2 - Décharge* | Décharge légale, validation éthique, checkbox déontologique HDS | Enregistrement du consentement horodaté dans `profiles.legal_consent_at` |
| **E3** | *Connexion & Inscription* | OAuth Google & Apple, saisie email pro hospitalier, badge HDS | Supabase Auth (Sign in with OAuth / Magic Link) |
| **E4** | *Chat IA Clinique* | Zone de messages streamés, sélecteur de sources (Bibliothèque/Web/Tous), pillules posologiques | SSE streaming depuis Edge Function `chat`, injection des citations `jsonb` |
| **E5** | *Bottom Sheet Sources* | Déploiement modal depuis les citations `[1]`, tri par onglets (RAG vs Web) | Affichage de l'extrait textuel, du score de similarité cosinus et lien source |
| **E6** | *Bibliothèque RAG* | Liste des protocoles/RCP, jauge de stockage Mo/quota, upload FAB | Stream Supabase Storage + table `documents` (statut d'indexation réactif) |
| **E7** | *Détail Document & Chunks* | Métadonnées du PDF, inspection des chunks vectorisés `pgvector`, bouton d'action chat | Fetch `document_chunks` triés par page et ordre d'ingestion, action purge |
| **E8** | *Sidebar & Historique* | Tiroir latéral inspiré Claude Mobile, regroupement temporel, profil médecin | Requête groupée sur `conversations` (Today, Last 7 days, Older) |
| **E9** | *Discussion Vocale & Orbe* | Plein écran immersif, orbe sensoriel réactif à la voix, transcription live | Audio STT (Whisper/Deepgram) -> LLM -> TTS vocal français naturel |
| **E10** | *Réglages & Paramètres* | Profil Dr. V. Marceau, switches des bases médicales (PubMed, ANSM, HAS), gestion du cache | Mise à jour de `profiles.preferences` (jsonb) |
| **E11** | *États Vides & Résilience* | Gestion de la perte de réseau, consultation du cache local AES-256 | Bascule automatique vers SQLite / WatermelonDB local dès rupture de signal |
| **E12** | *Connecteurs MCP (Phase 2)* | Configuration des serveurs Model Context Protocol distants | Stockage chiffré des tokens d'outils, exécution via Edge Function proxy |

---

## 3. Architecture Technique Cible

```
┌─────────────────────────────────────────────────────────────┐
│               FLUTTER APPLICATION MOBILE                    │
│   (Riverpod State Management + Drift/Hive Local Encrypted)  │
└──────────────┬───────────────────────────────┬──────────────┘
               │ HTTPS / WSS                   │ SSE (Streaming)
               ▼                               ▼
┌─────────────────────────────────────────────────────────────┐
│                  SUPABASE EDGE FUNCTIONS                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────┐  │
│  │   chat (SSE)     │  │ ingest-document  │  │ mcp-proxy │  │
│  └────────┬─────────┘  └────────┬─────────┘  └─────┬─────┘  │
└───────────┼─────────────────────┼──────────────────┼────────┘
            │                     │                  │
            ▼                     ▼                  ▼
┌───────────────────────┐ ┌────────────────┐ ┌────────────────┐
│   SUPABASE POSTGRES   │ │ ANTHROPIC CLAUDE│ │ SERVEURS MCP   │
│  - pgvector (HNSW)    │ │ (Claude Sonnet/ │ │ - PubMed API   │
│  - Row Level Security │ │  Opus Reasoning)│ │ - openFDA      │
│  - Storage (HDS Enc.) │ └────────────────┘ │ - HL7 / FHIR   │
└───────────────────────┘                    └────────────────┘
```

### 3.1 Base de Données Supabase & Sécurité RLS
- **Sécurité hermétique (RLS)** : Aucun praticien ne peut lire ou interroger les vecteurs d'un autre praticien.
```sql
-- Exemple de policy RLS sur les segments vectoriels
CREATE POLICY "Users access only own document chunks"
ON document_chunks FOR ALL
USING (auth.uid() = user_id);
```
- **Indexation Vectorielle HNSW** :
```sql
CREATE INDEX idx_document_chunks_embedding 
ON document_chunks 
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
```

### 3.2 Protocole de Cache & Mode Dégradé Hors-Ligne (Écran 11)
- Stockage local chiffré en **AES-256** (chiffrement matériel SQLCipher sur iOS/Android).
- Cache automatique des 100 derniers échanges cliniques et des PDF favoris.
- En cas de perte de connectivité :
  1. L'application bascule en lecture seule sur les documents déjà téléchargés.
  2. Les questions posées sont mises en file d'attente locale (`outbox_queue`).
  3. L'UI affiche la bannière dégradée bienveillante sans bloquer le médecin.
  4. Dès le retour du réseau, reprise automatique en tâche de fond (*background sync*).

---

## 4. Recommandations d'Implémentation Flutter

1. **Architecture des Dossiers (Clean Architecture / Feature-First)** :
   ```text
   lib/
   ├── core/
   │   ├── theme/          # Couleurs, typographie, espacements 2026
   │   ├── network/        # Client Supabase & intercepteur de tokens
   │   └── security/       # Gestionnaire du cache chiffré local
   ├── features/
   │   ├── auth/           # Onboarding, Connexion, Disclaimer
   │   ├── chat/           # Interface de conversation, bulles, citations
   │   ├── library/        # Gestionnaire RAG, upload, inspection chunks
   │   ├── voice/          # Orbe interactif, gestion micro et synthèse
   │   ├── settings/       # Paramètres, sources autorisées
   │   └── mcp/            # Connecteurs et diagnostic
   └── shared_widgets/     # Navbar flottante en verre dépoli, micro-badges
   ```
2. **Gestion de l'Orbe Vocal (Écran 9)** :
   - Utiliser un `CustomPainter` avec des gradients radiaux animés via `AnimationController` ou un shader GLSL léger pour simuler la pulsation sans surconsommation de batterie.
3. **Rendu Markdown Clinique** :
   - Utiliser `flutter_markdown` personnalisé avec des parseurs d'extensions pour convertir la syntaxe `[1]` en widgets cliquables natifs déclenchant le Bottom Sheet des sources.
