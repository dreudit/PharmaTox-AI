// =============================================================================
// DRUGS IA - EDGE FUNCTION `ingest-document`
// Déclenchée après l'upload d'un document dans le bucket Storage `documents` :
// extraction du texte (PDF/DOCX/TXT), découpage (~800 tokens, chevauchement
// 100), embeddings (Groq nomic-embed-text-v1_5, 768 dim), insertion dans
// `document_chunks`. Met à jour `documents.status` (pending -> indexing ->
// ready | error).
//
// Secret requis : GROQ_API_KEY
// =============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { extractText, getDocumentProxy } from 'npm:unpdf@0.12.1';
import JSZip from 'npm:jszip@3.10.1';

import { embedTexts } from '../_shared/groq.ts';

interface IngestRequestBody {
  documentId: string;
}

const CHARS_PER_CHUNK = 3200; // ~800 tokens (approximation ~4 caractères/token)
const CHARS_OVERLAP = 400; // ~100 tokens
const EMBEDDING_BATCH_SIZE = 20;

/// Découpe un texte en segments avec chevauchement, en respectant les mots.
function chunkText(text: string): string[] {
  const chunks: string[] = [];
  let start = 0;
  while (start < text.length) {
    const end = Math.min(start + CHARS_PER_CHUNK, text.length);
    chunks.push(text.slice(start, end).trim());
    if (end >= text.length) break;
    start = end - CHARS_OVERLAP;
  }
  return chunks.filter((c) => c.length > 0);
}

/// Extraction PDF : renvoie un tableau de texte, un élément par page.
async function extractPdfPages(buffer: Uint8Array): Promise<string[]> {
  const pdf = await getDocumentProxy(buffer);
  const { text } = await extractText(pdf, { mergePages: false });
  return Array.isArray(text) ? text : [text as unknown as string];
}

/// Extraction DOCX approximative : dézippe le document et retire les balises
/// XML de word/document.xml. Ne préserve ni tableaux ni mise en forme.
async function extractDocxText(buffer: Uint8Array): Promise<string> {
  const zip = await JSZip.loadAsync(buffer);
  const documentXml = await zip.file('word/document.xml')?.async('string');
  if (!documentXml) return '';
  const withBreaks = documentXml.replace(/<\/w:p>/g, '\n');
  const text = withBreaks.replace(/<[^>]+>/g, '');
  return text.replace(/\n{3,}/g, '\n\n').trim();
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
  const userId = userData.user.id;

  const { documentId } = (await req.json()) as IngestRequestBody;

  const { data: document, error: docError } = await supabase
    .from('documents')
    .select('*')
    .eq('id', documentId)
    .eq('user_id', userId)
    .single();

  if (docError || !document) {
    return new Response(JSON.stringify({ error: 'Document introuvable.' }), { status: 404 });
  }

  try {
    await supabase.from('documents').update({ status: 'indexing' }).eq('id', documentId);

    const { data: fileBlob, error: downloadError } = await supabase.storage
      .from('documents')
      .download(document.storage_path);
    if (downloadError || !fileBlob) {
      throw new Error(`Téléchargement impossible : ${downloadError?.message ?? 'fichier introuvable'}`);
    }
    const buffer = new Uint8Array(await fileBlob.arrayBuffer());

    let pages: string[];
    switch (document.file_format) {
      case 'PDF':
        pages = await extractPdfPages(buffer);
        break;
      case 'DOCX':
        pages = [await extractDocxText(buffer)];
        break;
      default:
        pages = [new TextDecoder().decode(buffer)];
    }

    const groqKey = Deno.env.get('GROQ_API_KEY');
    if (!groqKey) throw new Error('GROQ_API_KEY manquante.');

    type PendingChunk = {
      document_id: string;
      user_id: string;
      chunk_index: number;
      page_number: number;
      content: string;
      token_count: number;
      embedding?: number[];
    };

    const pendingChunks: PendingChunk[] = [];
    let chunkIndex = 0;
    for (let pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      const pageText = (pages[pageIdx] ?? '').trim();
      if (!pageText) continue;
      for (const content of chunkText(pageText)) {
        pendingChunks.push({
          document_id: documentId,
          user_id: userId,
          chunk_index: chunkIndex++,
          page_number: pageIdx + 1,
          content,
          token_count: Math.round(content.length / 4),
        });
      }
    }

    if (pendingChunks.length === 0) {
      throw new Error("Aucun texte n'a pu être extrait de ce document.");
    }

    // Embeddings par lots pour rester sous les limites de débit de l'API.
    for (let i = 0; i < pendingChunks.length; i += EMBEDDING_BATCH_SIZE) {
      const batch = pendingChunks.slice(i, i + EMBEDDING_BATCH_SIZE);
      const vectors = await embedTexts(batch.map((c) => c.content), groqKey);
      batch.forEach((chunk, idx) => {
        chunk.embedding = vectors[idx];
      });
    }

    const { error: insertError } = await supabase.from('document_chunks').insert(pendingChunks);
    if (insertError) throw insertError;

    await supabase
      .from('documents')
      .update({ status: 'ready', page_count: pages.length, error_message: null })
      .eq('id', documentId);

    return new Response(
      JSON.stringify({ status: 'ready', chunks: pendingChunks.length, pages: pages.length }),
      { headers: { 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    await supabase.from('documents').update({ status: 'error', error_message: String(err) }).eq('id', documentId);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
