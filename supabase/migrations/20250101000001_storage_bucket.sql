-- =============================================================================
-- DRUGS IA - BUCKET STORAGE PRIVÉ POUR LES DOCUMENTS
-- Séparé de 20250101000000_init_schema.sql : storage.buckets et
-- storage.objects appartiennent au rôle supabase_storage_admin. Isoler
-- cette section dans sa propre migration/transaction évite qu'un souci de
-- permission ici n'annule tout le schéma applicatif (tables, RLS) déjà créé.
-- =============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'documents',
    'documents',
    false, -- Bucket privé (URL signée requise)
    52428800, -- 50 Mo par fichier
    ARRAY['application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'text/plain']
)
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = 52428800;

-- RLS sur le Storage : chemin structuré strict 'user_id/...'
DROP POLICY IF EXISTS "Utilisateur accède uniquement à ses fichiers" ON storage.objects;
CREATE POLICY "Utilisateur accède uniquement à ses fichiers"
ON storage.objects FOR ALL TO authenticated
USING (bucket_id = 'documents' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'documents' AND (storage.foldername(name))[1] = auth.uid()::text);
