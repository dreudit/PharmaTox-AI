// =============================================================================
// DRUGS IA - HELPERS PARTAGÉS GROQ (embeddings)
// Importé par ingest-document, search-library et chat.
// =============================================================================

const EMBEDDING_MODEL = 'nomic-embed-text-v1_5'; // 768 dimensions par défaut

export async function embedTexts(texts: string[], groqKey: string): Promise<number[][]> {
  const res = await fetch('https://api.groq.com/openai/v1/embeddings', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      Authorization: `Bearer ${groqKey}`,
    },
    body: JSON.stringify({ model: EMBEDDING_MODEL, input: texts }),
  });

  if (!res.ok) {
    throw new Error(`Groq embeddings error (${res.status}): ${await res.text()}`);
  }

  const json = await res.json();
  return (json.data as Array<{ embedding: number[] }>).map((d) => d.embedding);
}

export async function embedText(text: string, groqKey: string): Promise<number[]> {
  const [vector] = await embedTexts([text], groqKey);
  return vector;
}
