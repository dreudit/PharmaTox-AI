// =============================================================================
// DRUGS IA - EDGE FUNCTION `ingest-document`
// Déclenchée après l'upload d'un document dans le bucket Storage `documents` :
// extraction du texte, découpage (~800 tokens, chevauchement 100), calcul des
// embeddings, insertion dans `document_chunks`. Met à jour `documents.status`
// (pending -> indexing -> ready | error) afin que l'UI reflète l'avancement.
// =============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

interface IngestRequestBody {
  documentId: string;
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

  const { documentId } = (await req.json()) as IngestRequestBody;

  const { data: document, error: docError } = await supabase
    .from('documents')
    .select('*')
    .eq('id', documentId)
    .eq('user_id', userData.user.id)
    .single();

  if (docError || !document) {
    return new Response(JSON.stringify({ error: "Document introuvable." }), { status: 404 });
  }

  try {
    await supabase.from('documents').update({ status: 'indexing' }).eq('id', documentId);

    // TODO pipeline réel :
    // 1. Télécharger le fichier depuis Storage (document.storage_path).
    // 2. Extraire le texte (pdf-parse / mammoth pour DOCX / lecture brute pour TXT).
    // 3. Découper en segments ~800 tokens avec chevauchement de 100.
    // 4. Calculer les embeddings (dimension 1536) pour chaque segment.
    // 5. Insérer les lignes dans `document_chunks` (chunk_index, page_number,
    //    section_title, content, token_count, embedding).

    await supabase.from('documents').update({ status: 'ready' }).eq('id', documentId);

    return new Response(JSON.stringify({ status: 'ready' }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    await supabase.from('documents').update({ status: 'error', error_message: String(err) }).eq('id', documentId);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
