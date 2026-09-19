// =============================================================================
// En-têtes CORS partagés par toutes les Edge Functions.
// Indispensable pour la version web (Firebase Hosting) : un navigateur
// bloque toute réponse cross-origin sans Access-Control-Allow-Origin, même
// si la requête elle-même a réussi côté serveur. L'app mobile n'est pas
// concernée (CORS n'existe que dans les navigateurs), d'où l'absence de
// symptôme jusqu'au déploiement web.
// =============================================================================

export const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

/// À appeler en tout premier dans chaque Deno.serve : répond directement à
/// la requête préliminaire (preflight) OPTIONS envoyée par le navigateur
/// avant toute requête POST cross-origin. Renvoie `null` pour les autres
/// méthodes, auquel cas le handler continue normalement.
export function handlePreflight(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  return null;
}
