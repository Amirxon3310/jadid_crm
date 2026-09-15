-- Enrollment status admin-only (2026-09-15): a group's own teacher manages
-- lessons, attendance and homework, but only an admin moves a student
-- between active/completed/left.
create or replace function private.set_enrollment_status(p_enrollment_id bigint,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare target public.enrollments;
begin
 select * into target from public.enrollments where id=p_enrollment_id;
 if auth.uid() is null or not found or not private.has_role(target.organization_id,array['admin'::public.app_role]) then
  raise exception 'Cannot manage this enrollment' using errcode='42501'; end if;
 if p_status is null or p_status not in ('active','completed','left') then raise exception 'Invalid enrollment status'; end if;
 update public.enrollments set study_status=p_status where id=target.id;
end; $$;
revoke all on function private.set_enrollment_status(bigint,text) from public,anon;
grant execute on function private.set_enrollment_status(bigint,text) to authenticated;
