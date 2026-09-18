// =============================================================================
// DRUGS IA - EDGE FUNCTION `chat`
// Reçoit un message, récupère le contexte RAG, appelle Claude avec le web
// search tool, streame la réponse en SSE et enregistre message + citations.
//
// Contrat SSE consommé par lib/core/network/sse_chat_client.dart :
//   event: init   data: {conversationId, messageId, citations, sourcesCount}
//   event: delta  data: {text}                (répété)
//   event: done   data: {conversationId, messageId, totalLength, latencyMs, citations}
//   event: error  data: {error}
//
// Secrets requis (supabase secrets set ...) :
//   ANTHROPIC_API_KEY
// =============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

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
9. Répondre dans la langue de l'utilisateur.`;

interface ChatRequestBody {
  message: string;
  conversationId?: string;
  sourcesMode?: 'all' | 'library_only' | 'web_only';
  documentId?: string;
  folderId?: string;
}

function sseEvent(event: string, data: unknown): string {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

Deno.serve(async (req: Request) => {
  const startedAt = Date.now();

  const authHeader = req.headers.get('Authorization') ?? '';
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return new Response('Unauthorized', { status: 401 });
  }
  const userId = userData.user.id;

  const body = (await req.json()) as ChatRequestBody;
  const { message, sourcesMode = 'all', documentId, folderId } = body;
  let conversationId = body.conversationId;

  const stream = new ReadableStream({
    async start(controller) {
      const push = (event: string, data: unknown) => controller.enqueue(new TextEncoder().encode(sseEvent(event, data)));

      try {
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

        // 3. Récupérer le contexte RAG (voir Edge Function `search-library`).
        //    TODO : embedding du message + appel à match_document_chunks().
        const citations: unknown[] = [];

        const messageId = crypto.randomUUID();
        push('init', { conversationId, messageId, citations, sourcesCount: citations.length });

        // 4. Appeler l'API Claude en streaming.
        const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY');
        if (!anthropicKey) throw new Error('ANTHROPIC_API_KEY manquante.');

        const claudeResponse = await fetch('https://api.anthropic.com/v1/messages', {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            'x-api-key': anthropicKey,
            'anthropic-version': '2023-06-01',
          },
          body: JSON.stringify({
            model: 'claude-sonnet-5',
            max_tokens: 2048,
            temperature: 0.3,
            system: SYSTEM_PROMPT,
            stream: true,
            messages: [{ role: 'user', content: message }],
          }),
        });

        if (!claudeResponse.ok || !claudeResponse.body) {
          throw new Error(`Claude API error: ${claudeResponse.status}`);
        }

        let fullText = '';
        const reader = claudeResponse.body.getReader();
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
              if (evt.type === 'content_block_delta' && evt.delta?.text) {
                fullText += evt.delta.text;
                push('delta', { text: evt.delta.text });
              }
            } catch {
              // fragment JSON partiel, ignoré
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
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
});
