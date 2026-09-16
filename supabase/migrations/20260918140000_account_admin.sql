-- Freeing a login, and changing a password (2026-09-18).
--
-- 1. delete_member removed the membership and the profile but left the row in
--    auth.users, so the login stayed taken for ever: adding the same pupil
--    again answered "this login is busy" with nobody to be seen using it.
-- 2. An admin could read a login but not reset a forgotten password. A
--    password cannot be read back — only its hash is stored — but it can be
--    replaced, which is what an admin actually needs.

create or replace function public.delete_member(p_membership_id bigint)
returns void language plpgsql security definer set search_path='' as $$
declare org uuid; actor bigint; victim public.memberships; freed uuid;
begin
  select * into victim from public.memberships where id=p_membership_id;
  if victim.id is null then raise exception 'Bunday foydalanuvchi topilmadi.'; end if;
  org := victim.organization_id;
  if not private.has_role(org, array['admin'::public.app_role]) then
    raise exception 'Faqat admin o''chira oladi.';
  end if;
  actor := private.current_membership_id(org);
  if actor = p_membership_id then
    raise exception 'O''zingizni o''chira olmaysiz.';
  end if;
  if victim.role = 'admin' and (
    select count(*) from public.memberships m
    where m.organization_id=org and m.role='admin') <= 1 then
    raise exception 'Oxirgi adminni o''chirib bo''lmaydi.';
  end if;

  delete from public.payments where student_membership_id=p_membership_id;
  delete from public.score_awards
    where student_membership_id=p_membership_id or created_by=p_membership_id;
  delete from public.lesson_checkins where teacher_membership_id=p_membership_id;
  delete from public.enrollments where student_membership_id=p_membership_id;

  update public.groups set teacher_membership_id=null
    where teacher_membership_id=p_membership_id;
  update public.attendance set marked_by=actor where marked_by=p_membership_id;
  update public.assignments set created_by=actor where created_by=p_membership_id;
  update public.assignment_results set reviewed_by=actor
    where reviewed_by=p_membership_id;

  delete from public.memberships where id=p_membership_id;
  delete from public.profiles p where p.id=victim.profile_id
    and not exists(select 1 from public.memberships m where m.profile_id=p.id)
    returning p.id into freed;

  -- The login lives in auth.users. Leaving it behind is what kept the name
  -- reserved after the person was gone.
  if freed is not null then
    delete from auth.identities where user_id = freed;
    delete from auth.users where id = freed;
  end if;
end; $$;

revoke all on function public.delete_member(bigint) from public, anon;
grant execute on function public.delete_member(bigint) to authenticated;

create or replace function public.set_account_password(
  p_profile_id uuid,
  p_password text
) returns void language plpgsql security definer set search_path='' as $$
declare org uuid;
begin
  select m.organization_id into org from public.memberships m
   where m.profile_id = p_profile_id limit 1;
  if org is null or not private.has_role(org, array['admin'::public.app_role]) then
    raise exception 'Admin huquqi kerak' using errcode='42501';
  end if;
  if length(coalesce(p_password,'')) < 4 then
    raise exception 'Parol kamida 4 ta belgidan iborat bo''lsin' using errcode='22023';
  end if;
  update auth.users
     set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')),
         updated_at = now()
   where id = p_profile_id;
  if not found then raise exception 'Akkaunt topilmadi' using errcode='42501'; end if;
end; $$;

revoke all on function public.set_account_password(uuid,text) from public, anon;
grant execute on function public.set_account_password(uuid,text) to authenticated;
