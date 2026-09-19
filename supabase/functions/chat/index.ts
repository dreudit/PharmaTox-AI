// =============================================================================
// DRUGS IA - EDGE FUNCTION `chat`
// Reçoit un message, récupère le contexte RAG (pgvector), interroge Groq
// (Llama 3.3 70B pour la bibliothèque seule, ou Groq Compound quand la
// recherche web est activée — celui-ci exécute sa propre recherche web et
// renvoie ses sources), streame la réponse en SSE et enregistre message +
// citations.
//
// Contrat SSE consommé par lib/core/network/sse_chat_client.dart :
//   event: init   data: {conversationId, messageId, citations, sourcesCount}
//   event: delta  data: {text}                (répété)
//   event: done   data: {conversationId, messageId, totalLength, latencyMs, citations}
//   event: error  data: {error}
//
// Secret requis : GROQ_API_KEY
// =============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

import { embedText } from '../_shared/groq.ts';
import { corsHeaders, handlePreflight } from '../_shared/cors.ts';

const LIBRARY_MODEL = 'llama-3.3-70b-versatile';
// groq/compound : recherche web intégrée (Tavily), plusieurs recherches par requête si
// nécessaire — utilisé en mode "Approfondi" pour une synthèse multi-sources façon Perplexity.
// groq/compound-mini : une seule recherche, ~3x plus rapide — mode "Rapide".
const WEB_MODEL_DEEP = 'groq/compound';
const WEB_MODEL_QUICK = 'groq/compound-mini';

// Liste blanche des domaines médicaux/réglementaires de confiance, activable
// individuellement dans Réglages > Sources web (profiles.preferences.allowed_web_sources).
const SOURCE_DOMAINS: Record<string, string[]> = {
  pubmed: ['pubmed.ncbi.nlm.nih.gov', 'ncbi.nlm.nih.gov'],
  ansm: ['ansm.sante.fr'],
  has: ['has-sante.fr'],
  openfda: ['fda.gov', 'open.fda.gov'],
  dailymed: ['dailymed.nlm.nih.gov'],
};
// Toujours inclus, indépendamment des réglages utilisateur (sources internationales
// de référence non désactivables) : EMA, OMS, PubChem, CDC/ATSDR, Cochrane.
const ALWAYS_INCLUDED_DOMAINS = [
  'ema.europa.eu',
  'who.int',
  'pubchem.ncbi.nlm.nih.gov',
  'cdc.gov',
  'atsdr.cdc.gov',
  'cochranelibrary.com',
];

const SYSTEM_PROMPT = `Tu es Drugs IA, un assistant expert en pharmacologie et toxicologie.

Règles obligatoires :
1. Sourcer toute affirmation clinique importante (dose, contre-indication, interaction, antidote) à partir de la bibliothèque de l'utilisateur ou du web. Sans source, le dire clairement.
2. Distinguer ce qui vient d'un document utilisateur, du web, et des connaissances générales.
3. Signaler l'incertitude et les divergences entre sources.
4. Ne donner des doses qu'avec source et population concernée ; rappeler de vérifier le RCP / la monographie officielle.
5. En cas de suspicion d'intoxication en cours, orienter d'abord vers les secours ou un centre antipoison, puis donner l'information éducative.
6. Ne jamais poser de diagnostic ni prescrire : ceci est un outil d'aide à l'information, pas un dispositif médical.
7. Refuser toute aide à un usage malveillant (empoisonner, synthétiser des toxiques, contourner des contrôles).
8. Refuser poliment les sujets hors pharmacologie/toxicologie et rediriger.
9. Répondre dans la langue de l'utilisateur.
10. Quand des extraits de bibliothèque te sont fournis ci-dessous, cite-les avec leur numéro [n].`;

const WEB_SEARCH_INSTRUCTIONS = `

Recherche web : croise plusieurs sources indépendantes avant de conclure sur un point clinique important (dose, interaction, alerte de pharmacovigilance). Préfère toujours la source la plus récente et la plus autoritative (agence réglementaire > méta-analyse/Cochrane > étude primaire). Indique la date de publication de chaque source quand elle est disponible, et signale explicitement si les sources se contredisent.`;

interface ChatRequestBody {
  message: string;
  conversationId?: string;
  sourcesMode?: 'all' | 'library_only' | 'web_only';
  searchMode?: 'quick' | 'deep';
  documentId?: string;
  folderId?: string;
}

interface Citation {
  citationNumber: number;
  type: 'rag' | 'web';
  title: string;
  subtitleOrAuthor?: string;
  documentName?: string;
  pageNumber?: number;
  sectionTitle?: string;
  url?: string;
  publicationDate?: string;
  relevanceScore?: number;
  excerptText: string;
}

function sseEvent(event: string, data: unknown): string {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

function truncate(text: string, max = 400): string {
  return text.length > max ? `${text.slice(0, max)}…` : text;
}

/// Traduit les erreurs Groq de quota/débit (413 « request too large » sur
/// les tokens/minute, 429 rate limit) en message clair pour l'utilisateur,
/// plutôt que de renvoyer le JSON brut de l'API.
async function groqErrorMessage(response: Response): Promise<string> {
  const bodyText = await response.text();
  if (response.status === 413 || response.status === 429) {
    return "Limite de débit Groq atteinte (trop de tokens/minute sur votre compte). Réessayez dans une minute, ou passez en mode « Rapide » qui consomme beaucoup moins de tokens par requête.";
  }
  return `Groq API error (${response.status}): ${bodyText}`;
}

/// Les modèles groq/compound* exécutent une vraie recherche web en interne
/// (appels à des moteurs de recherche tiers) et peuvent parfois traîner ou
/// rester bloqués bien plus longtemps qu'un appel LLM classique. Sans
/// limite de temps explicite, un tel blocage se traduit côté app par une
/// attente indéfinie ("recherche sans fin") plutôt qu'une erreur claire.
const GROQ_FETCH_TIMEOUT_MS = 28_000;

async function fetchWithTimeout(url: string, init: RequestInit, timeoutMs = GROQ_FETCH_TIMEOUT_MS): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } catch (err) {
    if (err instanceof DOMException && err.name === 'AbortError') {
      throw new Error(
        "La recherche web Groq n'a pas répondu à temps (>28s). Réessayez, idéalement en mode « Rapide », ou décochez « Web » pour interroger uniquement votre bibliothèque.",
      );
    }
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  const startedAt = Date.now();

  const authHeader = req.headers.get('Authorization') ?? '';
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return new Response('Unauthorized', { status: 401, headers: corsHeaders });
  }
  const userId = userData.user.id;

  const body = (await req.json()) as ChatRequestBody;
  const { message, sourcesMode = 'all', searchMode = 'deep', documentId, folderId } = body;
  let conversationId = body.conversationId;

  const wantsLibrary = sourcesMode === 'all' || sourcesMode === 'library_only';
  const wantsWeb = sourcesMode === 'all' || sourcesMode === 'web_only';

  const stream = new ReadableStream({
    async start(controller) {
      const push = (event: string, data: unknown) => controller.enqueue(new TextEncoder().encode(sseEvent(event, data)));

      try {
        const groqKey = Deno.env.get('GROQ_API_KEY');
        if (!groqKey) throw new Error('GROQ_API_KEY manquante.');

        // 1. Créer la conversation si nécessaire.
        if (!conversationId) {
          const { data: conv, error } = await supabase
            .from('conversations')
            .insert({ user_id: userId, sources_mode: sourcesMode, title: message.slice(0, 60) })
            .select('id')
            .single();
          if (error) throw error;
          conversationId = conv.id as string;
        }

        // 2. Enregistrer le message utilisateur.
        await supabase.from('messages').insert({
          conversation_id: conversationId,
          user_id: userId,
          sender: 'user',
          content: message,
        });

        // 3. Contexte RAG (bibliothèque personnelle).
        const citations: Citation[] = [];
        let ragContextBlock = '';

        if (wantsLibrary) {
          try {
            const queryEmbedding = await embedText(message, groqKey);
            const { data: matches } = await supabase.rpc('match_document_chunks', {
              query_embedding: queryEmbedding,
              match_threshold: 0.65,
              match_count: 8,
              p_user_id: userId,
              p_document_id: documentId ?? null,
              p_folder_id: folderId ?? null,
            });

            for (const row of (matches ?? []) as Array<{
              document_title: string;
              page_number: number;
              section_title: string | null;
              content: string;
              similarity: number;
            }>) {
              const citationNumber = citations.length + 1;
              citations.push({
                citationNumber,
                type: 'rag',
                title: row.document_title,
                documentName: row.document_title,
                pageNumber: row.page_number,
                sectionTitle: row.section_title ?? undefined,
                relevanceScore: row.similarity,
                excerptText: truncate(row.content),
              });
            }

            if (citations.length > 0) {
              ragContextBlock = `\n\nExtraits pertinents de la bibliothèque de l'utilisateur :\n${citations
                .map((c) => `[${c.citationNumber}] ${c.title} (page ${c.pageNumber}) : ${c.excerptText}`)
                .join('\n')}`;
            }
          } catch (ragErr) {
            // La recherche RAG ne doit jamais empêcher la réponse ; on continue sans contexte bibliothèque.
            console.error('RAG lookup failed', ragErr);
          }
        }

        const messageId = crypto.randomUUID();

        // 4. Appel au modèle Groq. Deux chemins selon le besoin de recherche web :
        //    - bibliothèque seule -> streaming token par token (llama-3.3-70b-versatile)
        //    - web activé -> Groq Compound (recherche web intégrée, croise plusieurs
        //      sources en mode "deep"), un seul appel non streamé pour récupérer les
        //      sources de façon fiable, puis re-diffusé en fragments côté serveur pour
        //      respecter le même contrat SSE.
        const systemContent = wantsWeb
          ? SYSTEM_PROMPT + WEB_SEARCH_INSTRUCTIONS + ragContextBlock
          : SYSTEM_PROMPT + ragContextBlock;
        const messages = [
          { role: 'system', content: systemContent },
          { role: 'user', content: message },
        ];

        let fullText = '';

        if (wantsWeb) {
          // Liste blanche des sources médicales : préférences utilisateur +
          // sources internationales toujours incluses.
          const { data: profile } = await supabase
            .from('profiles')
            .select('preferences')
            .eq('id', userId)
            .single();
          const allowedSources = (profile?.preferences?.allowed_web_sources ?? {}) as Record<string, boolean>;
          const includeDomains = [
            ...Object.entries(SOURCE_DOMAINS)
              .filter(([key]) => allowedSources[key] !== false) // activé par défaut si non renseigné
              .flatMap(([, domains]) => domains),
            ...ALWAYS_INCLUDED_DOMAINS,
          ];

          const webModel = searchMode === 'quick' ? WEB_MODEL_QUICK : WEB_MODEL_DEEP;

          const groqResponse = await fetchWithTimeout('https://api.groq.com/openai/v1/chat/completions', {
            method: 'POST',
            headers: { 'content-type': 'application/json', Authorization: `Bearer ${groqKey}` },
            body: JSON.stringify({
              model: webModel,
              max_tokens: 2048,
              temperature: 0.3,
              messages,
              search_settings: { include_domains: includeDomains },
            }),
          });

          if (!groqResponse.ok) {
            throw new Error(await groqErrorMessage(groqResponse));
          }

          const completion = await groqResponse.json();
          fullText = completion.choices?.[0]?.message?.content ?? '';

          const executedTools = completion.choices?.[0]?.message?.executed_tools as
            | Array<{
                search_results?: Array<{
                  title?: string;
                  url?: string;
                  content?: string;
                  snippet?: string;
                  published_date?: string;
                  score?: number;
                }>;
              }>
            | undefined;
          const webResults = executedTools?.flatMap((t) => t.search_results ?? []) ?? [];

          for (const result of webResults) {
            citations.push({
              citationNumber: citations.length + 1,
              type: 'web',
              title: result.title ?? result.url ?? 'Source web',
              url: result.url,
              publicationDate: result.published_date,
              relevanceScore: result.score,
              excerptText: truncate(result.content ?? result.snippet ?? ''),
            });
          }

          push('init', { conversationId, messageId, citations, sourcesCount: citations.length });

          // Re-diffusion en fragments pour respecter le contrat SSE côté app.
          const words = fullText.split(/(\s+)/);
          const FRAGMENT_SIZE = 6;
          for (let i = 0; i < words.length; i += FRAGMENT_SIZE) {
            push('delta', { text: words.slice(i, i + FRAGMENT_SIZE).join('') });
          }
        } else {
          push('init', { conversationId, messageId, citations, sourcesCount: citations.length });

          const groqResponse = await fetchWithTimeout('https://api.groq.com/openai/v1/chat/completions', {
            method: 'POST',
            headers: { 'content-type': 'application/json', Authorization: `Bearer ${groqKey}` },
            body: JSON.stringify({ model: LIBRARY_MODEL, max_tokens: 2048, temperature: 0.3, stream: true, messages }),
          });

          if (!groqResponse.ok || !groqResponse.body) {
            throw new Error(await groqErrorMessage(groqResponse));
          }

          const reader = groqResponse.body.getReader();
          const decoder = new TextDecoder();
          let buffer = '';

          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });

            const lines = buffer.split('\n');
            buffer = lines.pop() ?? '';

            for (const line of lines) {
              if (!line.startsWith('data: ')) continue;
              const dataStr = line.slice(6).trim();
              if (!dataStr || dataStr === '[DONE]') continue;
              try {
                const evt = JSON.parse(dataStr);
                const delta = evt.choices?.[0]?.delta?.content;
                if (delta) {
                  fullText += delta;
                  push('delta', { text: delta });
                }
              } catch {
                // fragment JSON partiel, ignoré
              }
            }
          }
        }

        const latencyMs = Date.now() - startedAt;

        // 5. Enregistrer la réponse de l'assistant.
        await supabase.from('messages').insert({
          conversation_id: conversationId,
          user_id: userId,
          sender: 'assistant',
          content: fullText,
          citations,
          latency_ms: latencyMs,
        });

        push('done', { conversationId, messageId, totalLength: fullText.length, latencyMs, citations });
      } catch (err) {
        push('error', { error: String(err) });
      } finally {
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
});
