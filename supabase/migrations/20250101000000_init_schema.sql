-- =============================================================================
-- DRUGS IA - MIGRATION INITIALE SUPABASE / POSTGRESQL
-- Extensions, tables, index HNSW/GIN, politiques RLS, bucket Storage.
-- Référence : docs/cahier-des-charges.md (sections 3, 5, 6.3)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. EXTENSIONS POSTGRESQL REQUISES
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";       -- Génération des UUIDs
CREATE EXTENSION IF NOT EXISTS "vector";          -- pgvector pour la recherche sémantique RAG
CREATE EXTENSION IF NOT EXISTS "pg_trgm";         -- Recherche par trigrammes et fuzzy matching
CREATE EXTENSION IF NOT EXISTS "unaccent";        -- Recherche plein texte insensible aux accents

-- -----------------------------------------------------------------------------
-- 2. PROFILS UTILISATEURS (liés à auth.users de Supabase)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    role_level TEXT NOT NULL DEFAULT 'student'
        CHECK (role_level IN ('student', 'professional', 'researcher')),
    language TEXT NOT NULL DEFAULT 'fr',
    preferences JSONB NOT NULL DEFAULT '{
        "response_style": "concise",
        "voice_name": "default",
        "voice_speed": 1.0,
        "offline_cache_enabled": true,
        "allowed_web_sources": {
            "pubmed": true,
            "ansm": true,
            "has": true,
            "openfda": true,
            "dailymed": false
        }
    }'::jsonb,
    legal_disclaimer_accepted_at TIMESTAMPTZ,
    hds_consent_accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Création automatique du profil lors de l'inscription Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name)
    VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 3. CONVERSATIONS & MESSAGES (streaming & citations)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'Nouvelle conversation',
    sources_mode TEXT NOT NULL DEFAULT 'all' CHECK (sources_mode IN ('all', 'library_only', 'web_only')),
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    is_archived BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_conversations_updated_at ON public.conversations;
CREATE TRIGGER trg_conversations_updated_at
    BEFORE UPDATE ON public.conversations
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    sender TEXT NOT NULL CHECK (sender IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    -- Citations structurées : [{citationNumber, type: 'rag'|'web', title, page, url, ...}]
    citations JSONB DEFAULT '[]'::jsonb,
    tool_calls JSONB DEFAULT '[]'::jsonb,
    educational_disclaimer TEXT,
    tokens_in INTEGER DEFAULT 0,
    tokens_out INTEGER DEFAULT 0,
    latency_ms INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 4. BIBLIOTHÈQUE RAG (F1) : dossiers, documents & segments vectorisés
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.folders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES public.folders(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    folder_id UUID REFERENCES public.folders(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Autre'
        CHECK (category IN ('Protocoles', 'Monographies', 'Toxidromes', 'Autre')),
    storage_path TEXT NOT NULL, -- Chemin relatif dans le bucket Storage 'documents'
    file_format TEXT NOT NULL DEFAULT 'PDF',
    size_bytes BIGINT NOT NULL DEFAULT 0,
    page_count INTEGER DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'indexing', 'ready', 'error')),
    error_message TEXT,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_documents_updated_at ON public.documents;
CREATE TRIGGER trg_documents_updated_at
    BEFORE UPDATE ON public.documents
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Segments vectoriels (~800 tokens, chevauchement 100). Dimension 1536
-- (text-embedding-3-small / Ada-002 — ajuster si un autre modèle est choisi).
CREATE TABLE IF NOT EXISTS public.document_chunks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    page_number INTEGER NOT NULL DEFAULT 1,
    section_title TEXT,
    content TEXT NOT NULL,
    token_count INTEGER NOT NULL DEFAULT 0,
    embedding vector(1536) NOT NULL,
    tsv tsvector GENERATED ALWAYS AS (to_tsvector('french', content)) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 5. CONNECTEURS MCP (Phase 2 — Écran 11 du cahier des charges)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mcp_servers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    host_url TEXT NOT NULL,
    description TEXT,
    vault_secret_id UUID, -- Référence au secret chiffré (Supabase Vault), jamais le jeton en clair
    is_read_only BOOLEAN NOT NULL DEFAULT true,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    available_tools JSONB DEFAULT '[]'::jsonb,
    latency_ms INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 6. LOGS D'USAGE & QUOTAS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.usage_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL CHECK (action_type IN ('chat_query', 'rag_ingestion', 'web_search', 'mcp_call', 'voice_tts')),
    tokens_consumed INTEGER DEFAULT 0,
    storage_delta_bytes BIGINT DEFAULT 0,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    rating SMALLINT CHECK (rating IN (-1, 1)),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 7. INDEX DE PERFORMANCE (HNSW pgvector, GIN plein texte, index relationnels)
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_document_chunks_embedding_hnsw
ON public.document_chunks
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_document_chunks_tsv
ON public.document_chunks USING gin (tsv);

CREATE INDEX IF NOT EXISTS idx_conversations_user_updated
ON public.conversations (user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_conv_created
ON public.messages (conversation_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_documents_user_status
ON public.documents (user_id, status);

CREATE INDEX IF NOT EXISTS idx_chunks_document_page
ON public.document_chunks (document_id, page_number);

-- -----------------------------------------------------------------------------
-- 8. RECHERCHE HYBRIDE RAG (vectorielle + plein texte)
-- Appelée par l'Edge Function `search-library`.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.match_document_chunks(
    query_embedding vector(1536),
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

-- -----------------------------------------------------------------------------
-- 9. ROW-LEVEL SECURITY — isolation stricte par utilisateur
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mcp_servers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Utilisateur gère son propre profil" ON public.profiles;
CREATE POLICY "Utilisateur gère son propre profil"
ON public.profiles FOR ALL TO authenticated
USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Utilisateur gère ses conversations" ON public.conversations;
CREATE POLICY "Utilisateur gère ses conversations"
ON public.conversations FOR ALL TO authenticated
USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Utilisateur lit et écrit ses messages" ON public.messages;
CREATE POLICY "Utilisateur lit et écrit ses messages"
ON public.messages FOR ALL TO authenticated
USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Utilisateur gère ses dossiers" ON public.folders;
CREATE POLICY "Utilisateur gère ses dossiers"
ON public.folders FOR ALL TO authenticated
USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Utilisateur gère ses documents" ON public.documents;
CREATE POLICY "Utilisateur gère ses documents"
ON public.documents FOR ALL TO authenticated
USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Isolation stricte des segments vectoriels" ON public.document_chunks;
CREATE POLICY "Isolation stricte des segments vectoriels"
ON public.document_chunks FOR ALL TO authenticated
USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Utilisateur gère ses serveurs MCP" ON public.mcp_servers;
CREATE POLICY "Utilisateur gère ses serveurs MCP"
ON public.mcp_servers FOR ALL TO authenticated
USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Utilisateur consulte ses propres logs" ON public.usage_logs;
CREATE POLICY "Utilisateur consulte ses propres logs"
ON public.usage_logs FOR SELECT TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Utilisateur insère ses propres logs" ON public.usage_logs;
CREATE POLICY "Utilisateur insère ses propres logs"
ON public.usage_logs FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Utilisateur gère son propre feedback" ON public.feedback;
CREATE POLICY "Utilisateur gère son propre feedback"
ON public.feedback FOR ALL TO authenticated
USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Le bucket Storage (section 10) est volontairement dans une migration
-- séparée (20250101000001_storage_bucket.sql) : storage.buckets et
-- storage.objects appartiennent au rôle supabase_storage_admin, et une
-- erreur de permission dessus ne doit jamais faire échouer/annuler tout
-- le schéma applicatif ci-dessus (le SQL Editor de Supabase exécute
-- chaque script dans une seule transaction).
