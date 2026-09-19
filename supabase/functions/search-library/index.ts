// =============================================================================
// DRUGS IA - EDGE FUNCTION `search-library`
// Recherche vectorielle dans les documents de l'utilisateur, filtrée par
// dossier ou document précis. Appelle la fonction SQL `match_document_chunks`
// (voir migrations) avec un embedding calculé via Groq (nomic-embed-text-v1_5).
//
// Secret requis : GROQ_API_KEY
// =============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

import { embedText } from '../_shared/groq.ts';
import { corsHeaders, handlePreflight } from '../_shared/cors.ts';

interface SearchRequestBody {
  query: string;
  documentId?: string;
  folderId?: string;
  matchCount?: number;
}

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

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

  const { query, documentId, folderId, matchCount = 8 } = (await req.json()) as SearchRequestBody;

  const groqKey = Deno.env.get('GROQ_API_KEY');
  if (!groqKey) {
    return new Response(JSON.stringify({ error: 'GROQ_API_KEY manquante.' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  let queryEmbedding: number[];
  try {
    queryEmbedding = await embedText(query, groqKey);
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 502,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const { data, error } = await supabase.rpc('match_document_chunks', {
    query_embedding: queryEmbedding,
    match_threshold: 0.65,
    match_count: matchCount,
    p_user_id: userData.user.id,
    p_document_id: documentId ?? null,
    p_folder_id: folderId ?? null,
  });

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  return new Response(JSON.stringify({ results: data }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
