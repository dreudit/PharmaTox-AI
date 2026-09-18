# Cahier des charges — App mobile IA Pharmacologie & Toxicologie

**Version** : 1.0 (MVP) · **Design** : Google Stitch · **Backend** : Claude Code + Supabase · **Langue de l'app** : français (anglais en second temps)

---

## 1. Vision

Une application mobile de type Claude / ChatGPT, mais **spécialisée exclusivement en pharmacologie et toxicologie**. L'utilisateur converse (texte ou voix) avec une IA qui :

1. raisonne à partir de **ses propres documents** (bibliothèque personnelle),
2. va chercher **les données les plus récentes et fiables sur le web**, avec sources citées, à la manière de Perplexity.

**Promesse** : des réponses précises, sourcées, vérifiables. Jamais de réponse pharmacologique importante sans référence.

**Public cible** : étudiants en médecine/pharmacie, médecins, pharmaciens, infirmiers, chercheurs.

---

## 2. Garde-fous de périmètre (règle anti-dispersion)

| Règle | Détail |
|---|---|
| **2 fonctions maximum** | F1 Bibliothèque de documents · F2 Recherche web sourcée. Tout le reste est du socle (chat, auth, réglages). |
| **Une seule spécialité** | Pharmacologie + toxicologie. L'IA décline poliment les sujets hors domaine. |
| **MCP = phase 2** | Architecture prête dès le MVP, exposition à l'utilisateur après validation. |
| **Pas de fonctionnalité sociale** | Ni partage public, ni communauté, ni marketplace. |
| **Critère de coupe** | Toute idée nouvelle doit améliorer F1 ou F2, sinon elle va dans le backlog « v2 ». |

---

## 3. Fonctionnalités

### 3.1 Socle (indispensable, pas comptées comme « fonctions »)

- Authentification (email + mot de passe, Google) via Supabase Auth
- Chat texte avec streaming des réponses
- Historique des conversations (sidebar)
- Discussion vocale
- Paramètres et profil
- Rendu Markdown, tableaux, formules chimiques simples, blocs d'avertissement

### 3.2 F1 — Bibliothèque

L'utilisateur téléverse des documents que l'IA peut consulter.

- **Formats** : PDF, DOCX, TXT, MD, images de pages (OCR) — MVP : PDF, DOCX, TXT
- **Limites MVP** : 50 Mo par fichier, 100 documents par utilisateur
- **Organisation** : dossiers simples, tags, recherche par titre
- **Statut d'indexation** visible : *en attente → en cours → prêt → erreur*
- **Utilisation dans le chat** : bouton « Sources » pour choisir *toute la bibliothèque*, *un dossier* ou *un document précis*
- **Citation** : chaque réponse basée sur la bibliothèque indique **document + page/section**
- **Suppression** : supprimer un document supprime aussi ses vecteurs

### 3.3 F2 — Recherche web sourcée

- L'IA décide (ou l'utilisateur force via un bouton) de chercher sur le web
- **Sources prioritaires (liste blanche configurable)** : PubMed / PMC, openFDA, DailyMed, EMA, ANSM, OMS, PubChem, CDC / ATSDR, Cochrane, HAS, revues à comité de lecture
- **Affichage** : réponse avec citations numérotées [1] [2]…, liste des sources en bas avec titre, domaine, date de publication et lien
- **Indicateur de fraîcheur** : date de la source la plus récente
- **Mode** : *Rapide* (1 recherche) ou *Approfondi* (plusieurs recherches, synthèse plus longue)
- **Combinaison** : une même réponse peut croiser bibliothèque et web, avec citations distinguées visuellement (icône document vs icône globe)

### 3.4 MCP (phase 2)

- L'app agit comme **client MCP** côté serveur (Edge Function), jamais directement depuis le téléphone
- MVP : 1 à 2 serveurs MCP pré-configurés (ex. PubMed)
- Phase 2 : écran « Connecteurs » où l'utilisateur ajoute un serveur MCP distant (URL + jeton), active/désactive chaque outil
- Sécurité : liste blanche, jetons chiffrés, confirmation avant tout appel d'outil non lecture seule

---

## 4. Écrans (base du brief Stitch)

Style : sobre, clinique, lisible, mode clair et sombre. Navigation inspirée de Claude/ChatGPT mobile.

| # | Écran | Contenu et comportement |
|---|---|---|
| 1 | **Splash / Onboarding** | 3 écrans : mission, sources citées, avertissement médical à accepter |
| 2 | **Connexion / Inscription** | Email, Google, mot de passe oublié |
| 3 | **Chat (écran principal)** | Zone de messages, champ de saisie, bouton pièce jointe, bouton micro, sélecteur de sources (Bibliothèque / Web / Les deux), bouton envoyer/stop |
| 4 | **Message enrichi** | Réponse Markdown, citations cliquables, bandeau « Information éducative » sur les sujets sensibles, actions : copier, régénérer, 👍/👎, enregistrer |
| 5 | **Sidebar (tiroir)** | Nouvelle conversation, recherche, historique groupé (Aujourd'hui / 7 jours / Plus ancien), accès Bibliothèque et Réglages, profil en bas |
| 6 | **Discussion vocale** | Plein écran, orbe animé (écoute / réflexion / parole), bouton couper le micro, bouton terminer, transcription en direct repliable |
| 7 | **Bibliothèque** | Liste dossiers/documents, statut d'indexation, bouton « + Ajouter », recherche, tri |
| 8 | **Détail document** | Métadonnées, statut, aperçu, dossier, tags, supprimer, « Discuter de ce document » |
| 9 | **Panneau Sources d'une réponse** | Bottom sheet listant les références (document ou URL, extrait, date) |
| 10 | **Réglages** | Compte, apparence (clair/sombre/auto), langue, voix (choix et vitesse), sources web autorisées, mode de réponse (concis/détaillé), niveau de l'utilisateur (étudiant/professionnel), données (exporter/supprimer), à propos |
| 11 | **Connecteurs MCP** *(phase 2)* | Liste des serveurs, statut, activer/désactiver |
| 12 | **États vides et erreurs** | Aucune conversation, bibliothèque vide, hors-ligne, quota atteint, échec d'indexation |

---

## 5. Comportement de l'IA

### 5.1 Rôle et ton

Assistant expert en pharmacologie (pharmacocinétique, pharmacodynamie, interactions, effets indésirables, pharmacovigilance, classes thérapeutiques) et en toxicologie (toxidromes, mécanismes de toxicité, antidotes, prise en charge, toxicologie environnementale et professionnelle). Précis, structuré, prudent. Adapte la profondeur au niveau déclaré de l'utilisateur.

### 5.2 Règles obligatoires (system prompt)

1. **Sourcer** : toute affirmation clinique importante (dose, contre-indication, interaction, antidote) doit s'appuyer sur une source de la bibliothèque ou du web. Sans source, l'IA le dit clairement.
2. **Distinguer** ce qui vient du document de l'utilisateur, du web, et des connaissances générales du modèle.
3. **Signaler l'incertitude** et les divergences entre sources.
4. **Doses** : donner les doses uniquement avec source et population concernée (adulte, enfant, insuffisance rénale…). Rappeler de vérifier le RCP / la monographie officielle.
5. **Urgence** : si la question évoque une intoxication en cours, l'IA affiche d'abord un message d'orientation vers les secours ou un centre antipoison local, puis donne l'information éducative.
6. **Limites** : pas de diagnostic ni de prescription personnalisée. L'app est un outil d'aide à l'information, pas un dispositif médical.
7. **Usage malveillant** : refus de toute aide visant à nuire (empoisonner quelqu'un, synthétiser des toxiques ou stupéfiants, contourner des contrôles). Les questions de sécurité, prévention et prise en charge restent autorisées.
8. **Hors domaine** : refus poli et redirection.
9. **Langue** : répond dans la langue de l'utilisateur.

### 5.3 Modèle

- Modèle : Claude (via API Anthropic), niveau « raisonnement » pour les réponses approfondies et niveau rapide pour les titres de conversation et reformulations
- Température basse (≤ 0.3) pour la cohérence factuelle
- Prompt caching sur le system prompt et le contexte stable

---

## 6. Architecture technique

### 6.1 Vue d'ensemble

```
App mobile ──HTTPS/SSE──▶ Supabase Edge Functions ──▶ API Claude
    │                          │        │                (+ web search tool)
    │                          │        └──▶ Serveurs MCP distants (phase 2)
    │                          └──▶ Postgres + pgvector (RLS)
    └── Supabase Auth / Storage (documents)
```

Aucune clé d'API dans l'app mobile. Tout passe par les Edge Functions.

### 6.2 Front mobile

- **Recommandation : Flutter** (un seul code iOS/Android, bon support du streaming et de l'audio). Stitch fournit le design, à convertir en widgets Flutter.
- Gestion d'état : Riverpod ou Bloc
- Streaming : Server-Sent Events depuis l'Edge Function `chat`
- Voix : reconnaissance vocale + synthèse vocale (voir 6.6)

### 6.3 Base de données (Supabase / Postgres)

| Table | Champs clés |
|---|---|
| `profiles` | id (= auth.uid), nom, niveau (étudiant/pro), langue, préférences (jsonb) |
| `conversations` | id, user_id, titre, sources_mode, created_at, updated_at, archived |
| `messages` | id, conversation_id, role, content, citations (jsonb), tool_calls (jsonb), tokens_in, tokens_out, created_at |
| `folders` | id, user_id, nom, parent_id |
| `documents` | id, user_id, folder_id, titre, storage_path, mime, taille, statut, pages, tags, created_at |
| `document_chunks` | id, document_id, user_id, contenu, page, section, embedding (vector), tsv (tsvector) |
| `mcp_servers` | id, user_id, nom, url, secret_ref, actif, outils_autorises (jsonb) |
| `usage_logs` | id, user_id, type, tokens, cout, created_at |
| `feedback` | id, message_id, note, commentaire |

**RLS obligatoire sur toutes les tables** : un utilisateur ne lit et n'écrit que ses lignes. Storage : bucket privé `documents`, chemin `user_id/…`.

### 6.4 Edge Functions

| Fonction | Rôle |
|---|---|
| `chat` | Reçoit le message, récupère le contexte (RAG), appelle Claude avec outils, streame la réponse, enregistre message et citations |
| `ingest-document` | Déclenchée à l'upload : extraction du texte, découpage (~800 tokens, chevauchement 100), embeddings, insertion |
| `search-library` | Recherche hybride (vectorielle + plein texte) filtrée par user, dossier ou document |
| `web-search` | Recherche web restreinte aux domaines autorisés, retourne extraits + métadonnées |
| `voice-token` / `stt` / `tts` | Gestion de la voix (selon fournisseur retenu) |
| `mcp-proxy` *(phase 2)* | Appel sécurisé des serveurs MCP |
| `usage-guard` | Quotas et limitation de débit |

### 6.5 RAG (Bibliothèque)

- Embeddings stockés dans **pgvector** (index HNSW)
- **Recherche hybride** (similarité vectorielle + BM25/tsvector), puis re-classement, top 8 à 12 passages
- Chaque passage garde `document`, `page`, `section` pour la citation
- Traitement asynchrone de l'ingestion (file d'attente Supabase ou `pg_cron`), avec statut visible dans l'app
- OCR pour les PDF scannés (phase 1.5 si nécessaire)

### 6.6 Voix

- **Reconnaissance** : service de transcription streaming (ou reconnaissance native du téléphone en solution de repli)
- **Synthèse** : voix naturelle en français
- Boucle : parole → texte → même pipeline que le chat → réponse condensée → lecture audio
- Coupure de parole (barge-in) souhaitable
- Les réponses vocales sont plus courtes et sans tableaux

### 6.7 Recherche web

Deux options techniques, à trancher au début de l'implémentation :

- **Option A** — Outil de recherche web natif de l'API Claude, avec liste de domaines autorisés et citations retournées
- **Option B** — API de recherche tierce (type Perplexity Sonar, Brave, Tavily) appelée par l'Edge Function, avec extraction des pages puis synthèse par Claude

Recommandation MVP : **Option A** (moins de pièces à maintenir), avec possibilité de basculer vers B si la qualité des sources médicales est insuffisante.

---

## 7. Exigences non fonctionnelles

| Domaine | Exigence |
|---|---|
| **Performance** | Premier token de réponse < 3 s (chat), indexation d'un PDF de 100 pages < 2 min |
| **Réseau faible** | Connexion intermittente : reprise de la conversation après coupure, envoi en file d'attente, écrans de chargement légers, compression des payloads |
| **Hors-ligne** | Lecture de l'historique et de la liste des documents disponible sans réseau |
| **Sécurité** | RLS, clés uniquement côté serveur, jetons MCP chiffrés, validation des uploads (type, taille), protection contre l'injection de prompt dans les documents et pages web |
| **Confidentialité** | Données isolées par utilisateur, export et suppression de compte fonctionnels, aucune donnée d'utilisateur utilisée pour entraîner un modèle |
| **Accessibilité** | Tailles de police ajustables, contraste AA, compatibilité lecteurs d'écran |
| **Coûts** | Quotas par utilisateur (messages/jour, Mo de bibliothèque), suivi dans `usage_logs`, alerte au seuil de dépense |
| **Observabilité** | Logs des Edge Functions, suivi des erreurs (Sentry ou équivalent), métriques d'usage |

---

## 8. Conformité et responsabilité

- Avertissement médical à l'onboarding (consentement enregistré) et rappel discret sous les réponses sensibles
- Mentions légales, CGU et politique de confidentialité avant publication sur les stores
- Positionnement : **outil éducatif et documentaire**, pas un dispositif médical
- Pour un usage clinique réel, prévoir une validation par des professionnels avant ouverture publique

---

## 9. Répartition du travail

| Acteur | Livrables |
|---|---|
| **Stitch** | Design system (couleurs, typographie, composants), écrans 1 à 12, mode clair/sombre, états vides et erreurs, export du code/CSS ou des visuels |
| **Claude Code** | Schéma SQL + RLS, Edge Functions, pipeline d'ingestion, RAG, intégration Claude + recherche web, quotas, tests, puis intégration Flutter des écrans Stitch |
| **Toi** | Arbitrages, validation des sources autorisées, relecture médicale des réponses types, jeu de test de 50 questions |

---

## 10. Feuille de route

| Phase | Contenu | Critère de sortie |
|---|---|---|
| **0 — Cadrage** (2-3 jours) | Décisions ouvertes (section 12), brief Stitch, nom de l'app | Décisions validées |
| **1 — Socle** (1-2 semaines) | Auth, chat texte streaming, historique, sidebar, réglages | Conversation complète de bout en bout |
| **2 — F1 Bibliothèque** (1-2 semaines) | Upload, ingestion, RAG, citations page/section | Réponse correcte et citée sur 10 documents test |
| **3 — F2 Web** (1 semaine) | Recherche web sourcée, liste blanche, indicateur de fraîcheur | 90 % des réponses avec ≥ 2 sources fiables |
| **4 — Voix** (1 semaine) | STT, TTS, écran vocal | Échange vocal fluide en français |
| **5 — Bêta fermée** (2 semaines) | 10-20 testeurs, correction, quotas | Aucun bug bloquant, jeu de 50 questions validé |
| **6 — MCP** (après bêta) | Connecteurs pré-configurés puis écran utilisateur | Un serveur MCP fonctionnel de bout en bout |

---

## 11. Critères d'acceptation du MVP

- [ ] Un utilisateur crée un compte, converse et retrouve son historique
- [ ] Un PDF téléversé est indexé et cité avec page dans les réponses
- [ ] Une question d'actualité (ex. nouvelle alerte de pharmacovigilance) déclenche une recherche web avec sources datées
- [ ] Toute réponse clinique importante contient au moins une référence, sinon elle l'indique
- [ ] Une question hors domaine est refusée poliment
- [ ] Une demande à visée malveillante est refusée
- [ ] Un utilisateur A ne peut jamais accéder aux données d'un utilisateur B (test RLS)
- [ ] La discussion vocale fonctionne en français
- [ ] Suppression de compte = suppression de toutes les données

---

## 12. Décisions ouvertes

1. **Nom de l'app** et identité visuelle
2. **Framework mobile** : Flutter (recommandé) ou autre
3. **Recherche web** : option A (native Claude) ou B (API tierce)
4. **Fournisseur de voix** (STT/TTS) et budget associé
5. **Modèle économique** : gratuit avec quotas, abonnement, ou usage privé
6. **Liste blanche des domaines médicaux** à valider
7. **Langues** : français seul au lancement, ou français + anglais
8. **Public** : usage personnel/étudiant d'abord, ou ouverture aux professionnels dès la bêta

---

## Annexe A — Brief à coller dans Stitch

> Conçois une application mobile d'assistant IA spécialisé en pharmacologie et toxicologie, dans l'esprit de Claude et ChatGPT mobile. Ambiance clinique, sobre, rassurante, très lisible. Modes clair et sombre. Écrans : onboarding en 3 étapes avec avertissement médical ; connexion ; chat principal (messages, champ de saisie, pièce jointe, micro, sélecteur de sources Bibliothèque/Web) ; message enrichi avec citations numérotées cliquables et bandeau d'information éducative ; sidebar avec historique groupé par date, recherche, accès Bibliothèque et Réglages ; discussion vocale plein écran avec orbe animé ; bibliothèque de documents (dossiers, statut d'indexation, ajout) ; détail d'un document ; bottom sheet des sources d'une réponse ; réglages (apparence, langue, voix, sources web, niveau utilisateur, données) ; états vides et erreurs. Priorité à la lisibilité des réponses longues (titres, tableaux, listes) et aux citations.

## Annexe B — Brief de démarrage pour Claude Code

> Crée le backend de l'app décrite dans `cahier-des-charges-app-ia-pharmaco-tox.md` avec Supabase. Étape 1 : migrations SQL (tables de la section 6.3), extension pgvector, index HNSW et GIN, politiques RLS strictes, bucket Storage privé. Étape 2 : Edge Function `chat` avec streaming SSE, appel à l'API Claude, system prompt de la section 5. Étape 3 : `ingest-document` et `search-library` (recherche hybride). Étape 4 : recherche web avec liste blanche de domaines. Ajoute des tests RLS et un jeu d'évaluation de 50 questions. Ne code aucune fonctionnalité hors des deux fonctions F1 et F2 et du socle.
