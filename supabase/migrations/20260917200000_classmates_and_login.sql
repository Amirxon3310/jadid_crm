-- Classmates, ranks, and reading a login (2026-09-17).
--
-- 1. A pupil could not see anyone else in their own group: enrolments are
--    readable only for oneself, membership visibility stops at one's teacher,
--    and group_rankings is staff-only. So the group list showed one name and
--    the rating board one row. Rather than open those tables to classmates —
--    which would also hand out phone numbers — this adds one function that
--    returns exactly what a board needs: who is in the group, their avatar,
--    their enrolment state and their points.
-- 2. An admin can read the login an account signs in with. It lives in
--    auth.users, which no client may read, so it comes through a function
--    that checks the caller is an admin first. A password cannot be read at
--    all: only its hash is stored, by design.

create or replace function public.group_classmates(p_group_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid; me bigint;
begin
  select organization_id into org from public.groups where id=p_group_id;
  if org is null then raise exception 'Guruh topilmadi' using errcode='42501'; end if;
  me := private.current_membership_id(org);
  if auth.uid() is null or me is null then
    raise exception 'Kirish kerak' using errcode='42501';
  end if;
  -- The caller must belong to the group: enrolled in it, or its staff.
  if not exists (
        select 1 from public.enrollments e
        where e.group_id = p_group_id and e.student_membership_id = me)
     and not private.can_manage_group(p_group_id) then
    raise exception 'Bu guruhda emassiz' using errcode='42501';
  end if;
  return (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'profile_id', m.profile_id,
          'membership_id', m.id,
          'enrollment_id', e.id,
          'full_name', p.full_name,
          'avatar_path', p.avatar_path,
          'study_status', e.study_status,
          'points', coalesce(t.coins, 0)
        )
        order by coalesce(t.coins, 0) desc, p.full_name
      ),
      '[]'::jsonb
    )
    from public.enrollments e
    join public.memberships m on m.id = e.student_membership_id
    join public.profiles p on p.id = m.profile_id
    left join private.coin_totals(org) t on t.member = m.id
    where e.group_id = p_group_id and m.role = 'student'
  );
end; $$;

revoke all on function public.group_classmates(bigint) from public, anon;
grant execute on function public.group_classmates(bigint) to authenticated;

create or replace function public.member_login(p_profile_id uuid)
returns text language plpgsql stable security definer set search_path='' as $$
declare org uuid; mail text;
begin
  select m.organization_id into org from public.memberships m
   where m.profile_id = p_profile_id limit 1;
  if org is null or not private.has_role(org, array['admin'::public.app_role]) then
    raise exception 'Admin huquqi kerak' using errcode='42501';
  end if;
  select u.email into mail from auth.users u where u.id = p_profile_id;
  if mail is null then return null; end if;
  -- A username account signs in with a non-deliverable address; an older
  -- account signs in with its real email.
  return case
    when split_part(mail, '@', 2) = 'login.jadid.invalid'
      then split_part(mail, '@', 1)
    else mail
  end;
end; $$;

revoke all on function public.member_login(uuid) from public, anon;
grant execute on function public.member_login(uuid) to authenticated;
