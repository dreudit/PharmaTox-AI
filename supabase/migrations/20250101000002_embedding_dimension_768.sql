-- =============================================================================
-- DRUGS IA - AJUSTEMENT DE LA DIMENSION VECTORIELLE (1536 -> 768)
-- Le fournisseur d'embeddings retenu est Groq (nomic-embed-text-v1_5, 768
-- dimensions par défaut), et non OpenAI/Anthropic (1536 dimensions).
-- Sûr à exécuter : aucune donnée n'a encore été ingérée dans document_chunks.
-- =============================================================================

DROP INDEX IF EXISTS idx_document_chunks_embedding_hnsw;

ALTER TABLE public.document_chunks
    ALTER COLUMN embedding TYPE vector(768);

CREATE INDEX IF NOT EXISTS idx_document_chunks_embedding_hnsw
ON public.document_chunks
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

DROP FUNCTION IF EXISTS public.match_document_chunks(vector(1536), float, int, uuid, uuid, uuid);

CREATE OR REPLACE FUNCTION public.match_document_chunks(
    query_embedding vector(768),
    match_threshold float DEFAULT 0.65,
    match_count int DEFAULT 8,
    p_user_id uuid DEFAULT NULL,
    p_document_id uuid DEFAULT NULL,
    p_folder_id uuid DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    document_id uuid,
    document_title text,
    page_number int,
    section_title text,
    content text,
    similarity float
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        dc.id,
        dc.document_id,
        d.title AS document_title,
        dc.page_number,
        dc.section_title,
        dc.content,
        1 - (dc.embedding <=> query_embedding) AS similarity
    FROM public.document_chunks dc
    JOIN public.documents d ON dc.document_id = d.id
    WHERE
        dc.user_id = COALESCE(p_user_id, auth.uid())
        AND (p_document_id IS NULL OR dc.document_id = p_document_id)
        AND (p_folder_id IS NULL OR d.folder_id = p_folder_id)
        AND (1 - (dc.embedding <=> query_embedding)) >= match_threshold
    ORDER BY dc.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;
