// =============================================================================
// DRUGS IA - EDGE FUNCTION `search-library`
// Recherche hybride (vectorielle + plein texte) dans les documents de
// l'utilisateur, filtrée par dossier ou document précis. Appelle la
// fonction SQL `match_document_chunks` (voir migration init_schema.sql).
// =============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

interface SearchRequestBody {
  query: string;
  documentId?: string;
  folderId?: string;
  matchCount?: number;
}

Deno.serve(async (req: Request) => {
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

  const { query, documentId, folderId, matchCount = 8 } = (await req.json()) as SearchRequestBody;

  // TODO : calculer l'embedding de `query` (ex. API d'embeddings Anthropic/OpenAI)
  // avant d'appeler match_document_chunks. Le vecteur ci-dessous est un
  // placeholder de dimension 1536 rempli de zéros.
  const queryEmbedding = new Array(1536).fill(0);

  const { data, error } = await supabase.rpc('match_document_chunks', {
    query_embedding: queryEmbedding,
    match_threshold: 0.65,
    match_count: matchCount,
    p_user_id: userData.user.id,
    p_document_id: documentId ?? null,
    p_folder_id: folderId ?? null,
  });

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  return new Response(JSON.stringify({ results: data }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
