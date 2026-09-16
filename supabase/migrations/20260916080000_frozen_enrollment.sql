-- Frozen enrolment (2026-09-16): a pupil may be paused in a group without
-- leaving it. Freezing is temporary, so unlike completing or leaving it does
-- not stamp an end date — otherwise the journal would read the pupil as no
-- longer belonging to the group from that day on.

alter table public.enrollments
  drop constraint if exists enrollments_study_status_check;
alter table public.enrollments add constraint enrollments_study_status_check
  check (study_status in ('active','frozen','completed','left'));

create or replace function private.sync_enrollment_state() returns trigger
language plpgsql set search_path='' as $$
begin
 -- Compatibility with clients using the previous ends_on field.
 if TG_OP='UPDATE' and new.study_status=old.study_status and new.ends_on is distinct from old.ends_on then
  new.study_status:=case when new.ends_on is null then 'active' else 'completed' end;
 elsif TG_OP='INSERT' and new.ends_on is not null and new.study_status='active' then new.study_status:='completed'; end if;
 new.ends_on:=case when new.study_status in ('active','frozen') then null else coalesce(new.ends_on,(now() at time zone 'Asia/Tashkent')::date) end;
 return new;
end; $$;

-- Still admin-only, as 20260915063000 made it; 'frozen' simply joins the
-- statuses an admin may set.
create or replace function private.set_enrollment_status(p_enrollment_id bigint,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare target public.enrollments;
begin
 select * into target from public.enrollments where id=p_enrollment_id;
 if auth.uid() is null or not found or not private.has_role(target.organization_id,array['admin'::public.app_role]) then
  raise exception 'Cannot manage this enrollment' using errcode='42501'; end if;
 if p_status is null or p_status not in ('active','frozen','completed','left') then
  raise exception 'Invalid enrollment status'; end if;
 update public.enrollments set study_status=p_status where id=target.id;
end; $$;
