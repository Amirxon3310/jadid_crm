-- Creating an account without signing into it (2026-09-18).
--
-- The app created accounts by signing them up from the browser, which signs
-- that account in. On the web gotrue announces every sign-in to the other
-- clients in the same browser, so the admin doing the work was thrown into
-- the new pupil's account. Restoring the admin's session afterwards loses the
-- race: the announcement arrives after the restore.
--
-- Here the account is made in the database, so no session for it is ever
-- created and nothing is announced. The existing trigger on auth.users still
-- writes the profile and the membership from the metadata below.
--
-- This also lifts the six-character floor GoTrue's sign-up endpoint enforces;
-- the centre hands out short numeric logins and passwords on paper.

create extension if not exists pgcrypto with schema extensions;

create or replace function public.create_account(
  p_login text,
  p_password text,
  p_name text,
  p_role text
) returns uuid language plpgsql security definer set search_path='' as $$
declare
  org uuid;
  new_id uuid := gen_random_uuid();
  mail text;
begin
  select m.organization_id into org from public.memberships m
   where m.profile_id = (select auth.uid()) limit 1;
  if org is null or not private.has_role(org, array['admin'::public.app_role]) then
    raise exception 'Admin huquqi kerak' using errcode='42501';
  end if;
  if p_role not in ('student','teacher') then
    raise exception 'Faqat o''quvchi yoki ustoz' using errcode='22023';
  end if;
  if p_login !~ '^[a-z0-9_]{3,32}$' then
    raise exception 'Login 3-32 ta lotin harfi, raqam yoki _ belgisidan iborat bo''lsin'
      using errcode='22023';
  end if;
  if length(coalesce(p_password,'')) < 4 then
    raise exception 'Parol kamida 4 ta belgidan iborat bo''lsin' using errcode='22023';
  end if;
  if length(coalesce(trim(p_name),'')) < 2 then
    raise exception 'Ism va familiyani kiriting' using errcode='22023';
  end if;

  mail := p_login || '@login.jadid.invalid';
  if exists (select 1 from auth.users u where u.email = mail) then
    raise exception 'Bu login band' using errcode='23505';
  end if;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', new_id, 'authenticated',
    'authenticated', mail,
    extensions.crypt(p_password, extensions.gen_salt('bf')),
    -- Confirmed at once: the address is not deliverable and nobody is going
    -- to click a link in it.
    now(),
    jsonb_build_object('provider','email','providers',jsonb_build_array('email')),
    jsonb_build_object(
      'full_name', trim(p_name),
      'username', p_login,
      'registration_role', p_role
    ),
    now(), now()
  );

  insert into auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), new_id,
    jsonb_build_object('sub', new_id::text, 'email', mail),
    'email', new_id::text, now(), now(), now()
  );

  return new_id;
end; $$;

revoke all on function public.create_account(text,text,text,text) from public, anon;
grant execute on function public.create_account(text,text,text,text) to authenticated;
