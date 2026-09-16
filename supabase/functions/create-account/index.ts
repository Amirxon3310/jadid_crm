// Creates a pupil's or a teacher's account on the server.
//
// The app used to sign the new account up from the browser, which signs that
// account in: on the web gotrue announces the sign-in to every client in the
// same browser, so the admin doing the work was thrown into the new account.
// Here the account is made with the service role, and no session for it ever
// reaches the browser.
//
// Deploy:  supabase functions deploy create-account
// It needs SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY,
// which Supabase provides to deployed functions automatically.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const LOGIN_DOMAIN = 'login.jadid.invalid';
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function reply(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  const authorization = req.headers.get('Authorization');
  if (!authorization) return reply({ error: 'Kirish kerak.' }, 401);

  const url = Deno.env.get('SUPABASE_URL')!;
  // Runs as the caller, so row security decides what they are.
  const asCaller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authorization } },
  });

  const { data: me } = await asCaller.auth.getUser();
  if (!me?.user) return reply({ error: 'Kirish kerak.' }, 401);

  const { data: membership } = await asCaller
    .from('memberships')
    .select('role, organization_id')
    .eq('profile_id', me.user.id)
    .maybeSingle();
  if (membership?.role !== 'admin') {
    return reply({ error: 'Admin huquqi kerak.' }, 403);
  }

  const { name, login, password, role } = await req.json();
  if (typeof name !== 'string' || name.trim().length < 2) {
    return reply({ error: 'Ism va familiyani kiriting.' }, 400);
  }
  if (typeof login !== 'string' || !/^[a-z0-9_]{3,32}$/.test(login.trim().toLowerCase())) {
    return reply({ error: 'Login 3–32 ta lotin harfi, raqam yoki _ belgisidan iborat bo‘lsin.' }, 400);
  }
  if (typeof password !== 'string' || password.length < 6) {
    return reply({ error: 'Parol kamida 6 ta belgidan iborat bo‘lsin.' }, 400);
  }
  if (role !== 'student' && role !== 'teacher') {
    return reply({ error: 'Faqat o‘quvchi yoki ustoz.' }, 400);
  }

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error } = await admin.auth.admin.createUser({
    email: `${login.trim().toLowerCase()}@${LOGIN_DOMAIN}`,
    password,
    email_confirm: true,
    user_metadata: {
      full_name: name.trim(),
      username: login.trim().toLowerCase(),
      registration_role: role,
    },
  });
  if (error) {
    const taken = /already|exists|registered/i.test(error.message);
    return reply(
      { error: taken ? 'Bu login band. Boshqa login tanlang.' : error.message },
      taken ? 409 : 400,
    );
  }
  return reply({ ok: true }, 200);
});
