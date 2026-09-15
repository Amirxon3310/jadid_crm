-- Member removal and answer files (2026-09-17).
--
-- 1. An admin can remove a pupil or a teacher from the centre. History a
--    removed teacher signed (attendance they marked, homework they set) is
--    handed to the admin doing the removal rather than deleted, so the
--    group's own record stays intact.
-- 2. A pupil may attach a file to a homework answer, in the same bucket the
--    teacher's task sheet lives in.

alter table public.assignment_results add column file_path text;
alter table public.assignment_results add column file_name text;

-- Uploading was staff-only; a pupil enrolled in the group may now upload too.
create or replace function private.can_upload_homework_file(p_path text)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare grp bigint;
begin
 if auth.uid() is null or split_part(p_path,'/',2)!~'^[0-9]+$' then return false; end if;
 grp := split_part(p_path,'/',2)::bigint;
 return private.can_access_group(grp) and exists(
  select 1 from public.groups g where g.id=grp and g.organization_id::text=split_part(p_path,'/',1));
end; $$;

create function public.delete_member(p_membership_id bigint)
returns void language plpgsql security definer set search_path='' as $$
declare org uuid; actor bigint; victim public.memberships;
begin
  select * into victim from public.memberships where id=p_membership_id;
  if victim.id is null then raise exception 'Bunday foydalanuvchi topilmadi.'; end if;
  org := victim.organization_id;
  if not private.has_role(org, array['admin'::public.app_role]) then
    raise exception 'Faqat admin o‘chira oladi.';
  end if;
  actor := private.current_membership_id(org);
  if actor = p_membership_id then
    raise exception 'O‘zingizni o‘chira olmaysiz.';
  end if;
  if victim.role = 'admin' and (
    select count(*) from public.memberships m
    where m.organization_id=org and m.role='admin') <= 1 then
    raise exception 'Oxirgi adminni o‘chirib bo‘lmaydi.';
  end if;

  -- Rows that belong to the person alone.
  delete from public.payments where student_membership_id=p_membership_id;
  delete from public.score_awards
    where student_membership_id=p_membership_id or created_by=p_membership_id;
  delete from public.lesson_checkins where teacher_membership_id=p_membership_id;
  -- Attendance and homework results hang off the enrollment and cascade.
  delete from public.enrollments where student_membership_id=p_membership_id;

  -- Rows that belong to a group and only carry the person's signature.
  update public.groups set teacher_membership_id=null
    where teacher_membership_id=p_membership_id;
  update public.attendance set marked_by=actor where marked_by=p_membership_id;
  update public.assignments set created_by=actor where created_by=p_membership_id;
  update public.assignment_results set reviewed_by=actor
    where reviewed_by=p_membership_id;

  delete from public.memberships where id=p_membership_id;
  -- The profile goes too once no centre holds the person, so they disappear
  -- from every list. The Auth login itself can only be removed from the
  -- Supabase dashboard.
  delete from public.profiles p where p.id=victim.profile_id
    and not exists(select 1 from public.memberships m where m.profile_id=p.id);
end; $$;

revoke all on function public.delete_member(bigint) from public, anon;
grant execute on function public.delete_member(bigint) to authenticated;
