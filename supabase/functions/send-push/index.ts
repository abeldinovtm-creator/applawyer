// Supabase Edge Function — отправка FCM push-уведомлений
//
// Секреты (Supabase Dashboard → Settings → Edge Functions → Secrets):
//   FIREBASE_SERVICE_ACCOUNT — JSON сервисного аккаунта Firebase
//     (Firebase Console → Project Settings → Service accounts → Generate new private key)
//
// Вызывается из SQL-триггеров через pg_net

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

Deno.serve(async (req) => {
  try {
    const { recipient_id, title, body } = await req.json();
    if (!recipient_id || !title) {
      return json({ error: 'recipient_id and title are required' }, 400);
    }

    // Получаем FCM токен получателя
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: profile } = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('id', recipient_id)
      .maybeSingle();

    if (!profile?.fcm_token) {
      return json({ skipped: 'no_fcm_token' });
    }

    // Получаем access token для FCM HTTP v1 API
    const serviceAccountRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!serviceAccountRaw) {
      return json({ error: 'FIREBASE_SERVICE_ACCOUNT secret not set' }, 500);
    }

    const serviceAccount = JSON.parse(serviceAccountRaw);
    const accessToken = await getFcmAccessToken(serviceAccount);
    const projectId = serviceAccount.project_id;

    // Отправляем push через FCM HTTP v1
    const fcmResp = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: profile.fcm_token,
            notification: { title, body: body ?? '' },
            webpush: {
              notification: {
                icon: 'https://applawyer.online/icons/Icon-192.png',
                badge: 'https://applawyer.online/icons/Icon-192.png',
                requireInteraction: false,
              },
              fcm_options: { link: 'https://applawyer.online' },
            },
          },
        }),
      },
    );

    const result = await fcmResp.json();

    if (!fcmResp.ok) {
      // Токен устарел — чистим из БД
      if (result?.error?.details?.[0]?.errorCode === 'UNREGISTERED') {
        await supabase.from('profiles').update({ fcm_token: null }).eq('id', recipient_id);
      }
      return json({ error: result }, 500);
    }

    return json({ success: true, fcm: result });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// Генерирует OAuth2 access token из сервисного аккаунта Firebase (RS256 JWT)
async function getFcmAccessToken(sa: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const b64url = (input: Uint8Array | string): string => {
    const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
    let bin = '';
    bytes.forEach((b) => (bin += String.fromCharCode(b)));
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  };

  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));

  const unsigned = `${header}.${payload}`;

  const pemBody = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const sigBuf = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );

  const sig = b64url(new Uint8Array(sigBuf));
  const jwt = `${unsigned}.${sig}`;

  const tokenResp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const { access_token } = await tokenResp.json();
  return access_token;
}
