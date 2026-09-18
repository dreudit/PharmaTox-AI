// =============================================================================
// DRUGS IA - EDGE FUNCTION `stt` (Speech-to-Text)
// Transcrit un enregistrement audio (discussion vocale, Écran 6) via l'API
// Whisper de Groq (rapide, tier gratuit disponible). Le fichier audio est
// reçu en multipart/form-data depuis l'app Flutter (speech_to_text côté
// natif reste la solution de repli hors-ligne : voir lib/features/voice).
//
// Secret requis (supabase secrets set GROQ_API_KEY=...) : GROQ_API_KEY
// Ne jamais exposer cette clé côté client : elle ne doit vivre que dans les
// secrets de cette Edge Function.
// =============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

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

  const groqKey = Deno.env.get('GROQ_API_KEY');
  if (!groqKey) {
    return new Response(JSON.stringify({ error: 'GROQ_API_KEY manquante côté serveur.' }), { status: 500 });
  }

  const incomingForm = await req.formData();
  const audioFile = incomingForm.get('audio');
  if (!(audioFile instanceof File)) {
    return new Response(JSON.stringify({ error: "Champ 'audio' manquant ou invalide." }), { status: 400 });
  }

  const language = (incomingForm.get('language') as string) ?? 'fr';

  const groqForm = new FormData();
  groqForm.set('file', audioFile, audioFile.name || 'audio.webm');
  groqForm.set('model', 'whisper-large-v3-turbo');
  groqForm.set('language', language);
  groqForm.set('response_format', 'json');

  const groqResponse = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${groqKey}` },
    body: groqForm,
  });

  if (!groqResponse.ok) {
    const errBody = await groqResponse.text();
    return new Response(JSON.stringify({ error: `Groq STT error (${groqResponse.status}): ${errBody}` }), {
      status: 502,
    });
  }

  const result = await groqResponse.json();
  return new Response(JSON.stringify({ text: result.text ?? '' }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
