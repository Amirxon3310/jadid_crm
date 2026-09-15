-- Structured group/enrollment state preserves historical access.
alter table public.groups add column status text not null default 'active'
 check (status in ('active','completed','frozen'));
update public.groups set status='completed' where not is_active;
alter table public.groups add column week_days integer[] not null default '{}'
 check (week_days <@ array[1,2,3,4,5,6,7]);
alter table public.enrollments add column study_status text not null default 'active'
 check (study_status in ('active','completed','left'));
update public.enrollments set study_status='completed' where ends_on is not null;

create function private.sync_group_state() returns trigger language plpgsql set search_path='' as $$
begin
 new.is_active := new.status='active';
 if new.teacher_membership_id is not null and not exists (
   select 1 from public.memberships m where m.id=new.teacher_membership_id
    and m.organization_id=new.organization_id and m.is_active and m.role in ('teacher','admin')
 ) then raise exception 'Assign an active teacher'; end if;
 return new;
end; $$;
create trigger sync_group_state before insert or update on public.groups
 for each row execute function private.sync_group_state();
create function private.sync_enrollment_state() returns trigger language plpgsql set search_path='' as $$
begin
 -- Compatibility with clients using the previous ends_on field.
 if TG_OP='UPDATE' and new.study_status=old.study_status and new.ends_on is distinct from old.ends_on then
  new.study_status:=case when new.ends_on is null then 'active' else 'completed' end;
 elsif TG_OP='INSERT' and new.ends_on is not null and new.study_status='active' then new.study_status:='completed'; end if;
 new.ends_on:=case when new.study_status='active' then null else coalesce(new.ends_on,(now() at time zone 'Asia/Tashkent')::date) end;
 return new;
end; $$;
create trigger sync_enrollment_state before insert or update on public.enrollments
 for each row execute function private.sync_enrollment_state();
create function private.set_enrollment_status(p_enrollment_id bigint,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare target public.enrollments;
begin
 select * into target from public.enrollments where id=p_enrollment_id;
 if auth.uid() is null or not found or not private.can_manage_group(target.group_id) then
  raise exception 'Cannot manage this enrollment' using errcode='42501'; end if;
 if p_status is null or p_status not in ('active','completed','left') then raise exception 'Invalid enrollment status'; end if;
 update public.enrollments set study_status=p_status where id=target.id;
end; $$;
create function public.set_enrollment_status(p_enrollment_id bigint,p_status text)
returns void language sql security invoker set search_path='' as $$ select private.set_enrollment_status(p_enrollment_id,p_status); $$;
create or replace function private.set_enrollment_completed(p_enrollment_id bigint,p_completed boolean)
returns void language sql security definer set search_path='' as $$
 select private.set_enrollment_status(p_enrollment_id,case when p_completed then 'completed' else 'active' end); $$;

-- Lesson links cannot cross groups or organizations. Existing unlinked work remains readable.
alter table public.lessons add constraint lessons_id_group_org_key unique(id,group_id,organization_id);
alter table public.assignments add column lesson_id bigint;
alter table public.assignments add constraint assignments_lesson_group_fk
 foreign key(lesson_id,group_id,organization_id) references public.lessons(id,group_id,organization_id);
create index assignments_lesson_group_idx on public.assignments(lesson_id,group_id,organization_id);

create function private.can_work_in_group(p_group_id bigint) returns boolean
language sql stable security definer set search_path='' as $$
 select private.can_manage_group(p_group_id) and exists(select 1 from public.groups where id=p_group_id and status='active'); $$;
create policy lessons_active_insert on public.lessons as restrictive for insert to authenticated
 with check ((select private.can_work_in_group(group_id)));
create policy assignments_active_insert on public.assignments as restrictive for insert to authenticated
 with check ((select private.can_work_in_group(group_id)));
create function private.validate_lesson_schedule() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if TG_OP='UPDATE' and (new.group_id<>old.group_id or new.starts_at<>old.starts_at) and
   (exists(select 1 from public.attendance where lesson_id=old.id) or exists(select 1 from public.lesson_checkins where lesson_id=old.id)) then
  raise exception 'A recorded lesson cannot be rescheduled'; end if;
 if (TG_OP='INSERT' or new.starts_at<>old.starts_at or new.group_id<>old.group_id) and exists(
  select 1 from public.groups where id=new.group_id and cardinality(week_days)>0
   and not (extract(isodow from new.starts_at at time zone 'Asia/Tashkent')::integer=any(week_days))
 ) then raise exception 'Select a scheduled lesson day'; end if;
 return new;
end; $$;

-- A teacher checks in on today's scheduled lesson using a private photo.
create table public.lesson_checkins (
 id bigint generated always as identity primary key,
 organization_id uuid not null references public.organizations(id),
 lesson_id bigint not null,
 teacher_membership_id bigint not null,
 photo_path text not null unique,
 checked_at timestamptz not null default now(),
 unique(lesson_id,teacher_membership_id),
 foreign key(lesson_id,organization_id) references public.lessons(id,organization_id),
 foreign key(teacher_membership_id,organization_id) references public.memberships(id,organization_id)
);
create index lesson_checkins_teacher_org_idx on public.lesson_checkins(teacher_membership_id,organization_id);
create index lesson_checkins_lesson_org_idx on public.lesson_checkins(lesson_id,organization_id);
create index lesson_checkins_org_idx on public.lesson_checkins(organization_id);
alter table public.lesson_checkins enable row level security;
grant select on public.lesson_checkins to authenticated;
revoke insert,update,delete on public.lesson_checkins from anon,authenticated;
create policy checkins_read_staff on public.lesson_checkins for select to authenticated
 using (exists(select 1 from public.lessons l where l.id=lesson_id and private.can_manage_group(l.group_id)));
create trigger validate_lesson_schedule before insert or update on public.lessons
 for each row execute function private.validate_lesson_schedule();

create function private.can_check_in(p_lesson_id bigint) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.lessons l join public.groups g on g.id=l.group_id
 join public.memberships m on m.id=g.teacher_membership_id
 where l.id=p_lesson_id and m.profile_id=(select auth.uid()) and m.is_active and m.role='teacher'
 and g.status='active' and l.status<>'cancelled'
 and (l.starts_at at time zone 'Asia/Tashkent')::date=(now() at time zone 'Asia/Tashkent')::date
 and (cardinality(g.week_days)=0 or extract(isodow from l.starts_at at time zone 'Asia/Tashkent')::integer=any(g.week_days)));
$$;
create function private.can_upload_checkin(p_path text) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare lesson bigint;
begin
 if auth.uid() is null or split_part(p_path,'/',1)<>auth.uid()::text or split_part(p_path,'/',2)!~'^[0-9]+$' then return false; end if;
 lesson:=split_part(p_path,'/',2)::bigint;
 return private.can_check_in(lesson) and not exists(select 1 from public.lesson_checkins where lesson_id=lesson
  and teacher_membership_id=private.current_membership_id(organization_id));
exception when numeric_value_out_of_range then return false;
end; $$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('lesson-checkins','lesson-checkins',false,3145728,array['image/jpeg','image/png']);
create policy checkin_photo_upload on storage.objects for insert to authenticated
 with check(bucket_id='lesson-checkins' and (select private.can_upload_checkin(name)));
create policy checkin_photo_read on storage.objects for select to authenticated
 using(bucket_id='lesson-checkins' and exists(select 1 from public.lesson_checkins c where c.photo_path=name));
-- Only unused failed uploads can be removed by their owner; recorded photos remain immutable.
create function private.can_remove_checkin_photo(p_path text) returns boolean
language sql stable security definer set search_path='' as $$
 select split_part(p_path,'/',1)=(select auth.uid())::text and not exists(
 select 1 from public.lesson_checkins where photo_path=p_path); $$;
revoke all on function private.can_remove_checkin_photo(text) from public,anon;
grant execute on function private.can_remove_checkin_photo(text) to authenticated;
create policy checkin_photo_cleanup on storage.objects for delete to authenticated
 using(bucket_id='lesson-checkins' and (select private.can_remove_checkin_photo(name)));
create function private.check_in_lesson(p_lesson_id bigint,p_photo_path text)
returns void language plpgsql security definer set search_path='' as $$
declare org uuid; member bigint;
begin
 if not private.can_check_in(p_lesson_id) then raise exception 'Check in on your scheduled lesson day' using errcode='42501'; end if;
 select organization_id into org from public.lessons where id=p_lesson_id;
 member:=private.current_membership_id(org);
 if split_part(p_photo_path,'/',1)<>auth.uid()::text or split_part(p_photo_path,'/',2)<>p_lesson_id::text or not exists(
   select 1 from storage.objects where bucket_id='lesson-checkins' and name=p_photo_path
    and created_at>=date_trunc('day',now() at time zone 'Asia/Tashkent') at time zone 'Asia/Tashkent'
 ) then raise exception 'Take a new photo for this lesson'; end if;
 insert into public.lesson_checkins(organization_id,lesson_id,teacher_membership_id,photo_path)
 values(org,p_lesson_id,member,p_photo_path);
end; $$;
create function public.check_in_lesson(p_lesson_id bigint,p_photo_path text)
returns void language sql security invoker set search_path='' as $$ select private.check_in_lesson(p_lesson_id,p_photo_path); $$;
create function private.can_mark_lesson(p_lesson_id bigint) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.lessons l where l.id=p_lesson_id and
 (private.has_role(l.organization_id,array['admin'::public.app_role]) or
  (private.can_check_in(l.id) and exists(select 1 from public.lesson_checkins c
    where c.lesson_id=l.id and c.teacher_membership_id=private.current_membership_id(l.organization_id)
    and (c.checked_at at time zone 'Asia/Tashkent')::date=(now() at time zone 'Asia/Tashkent')::date)))); $$;
create policy attendance_teacher_checkin_insert on public.attendance as restrictive for insert to authenticated
 with check((select private.can_mark_lesson(lesson_id)) and marked_by=(select private.current_membership_id(organization_id)));
create policy attendance_teacher_checkin_update on public.attendance as restrictive for update to authenticated
 using((select private.can_mark_lesson(lesson_id)))
 with check((select private.can_mark_lesson(lesson_id)) and marked_by=(select private.current_membership_id(organization_id)));
create policy attendance_matching_group on public.attendance as restrictive for all to authenticated
 using(exists(select 1 from public.enrollments e join public.lessons l on l.group_id=e.group_id where e.id=enrollment_id and l.id=lesson_id))
 with check(exists(select 1 from public.enrollments e join public.lessons l on l.group_id=e.group_id where e.id=enrollment_id and l.id=lesson_id
  and (e.study_status='active' or private.has_role(e.organization_id,array['admin'::public.app_role]))));
create or replace function private.can_submit_result(p_assignment bigint,p_enrollment bigint)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.enrollments e
 join public.assignments a on a.group_id=e.group_id and a.organization_id=e.organization_id
 join public.groups g on g.id=e.group_id
 join public.memberships m on m.id=e.student_membership_id
 where e.id=p_enrollment and a.id=p_assignment and e.study_status='active' and g.status='active'
 and m.profile_id=(select auth.uid()) and m.is_active and m.role='student'); $$;

-- Derived coins cannot be duplicated by repeated attendance upserts.
create function private.coin_totals(p_org uuid) returns table(member bigint,coins bigint)
language sql stable security definer set search_path='' as $$
 with points as (
 select e.student_membership_id as member,coalesce(r.score,0)::bigint as coins
 from public.assignment_results r join public.enrollments e on e.id=r.enrollment_id
 where r.organization_id=p_org and r.status='accepted'
 union all
 select e.student_membership_id,10::bigint from public.attendance a
 join public.enrollments e on e.id=a.enrollment_id
 join public.lessons l on l.id=a.lesson_id and l.group_id=e.group_id
 where a.organization_id=p_org and a.status in ('present','late') and l.status<>'cancelled'
 ) select m.id,coalesce(sum(p.coins),0)::bigint from public.memberships m left join points p on p.member=m.id
 where m.organization_id=p_org and m.role='student' and m.is_active group by m.id;
$$;
revoke all on function private.coin_totals(uuid) from public,anon,authenticated;
create or replace function private.student_rankings(p_organization_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare me bigint; result jsonb;
begin
 me:=private.current_membership_id(p_organization_id);
 if auth.uid() is null or me is null or not private.has_role(p_organization_id,array['student'::public.app_role]) then
  raise exception 'Student membership required' using errcode='42501'; end if;
 with totals as materialized(select * from private.coin_totals(p_organization_id)), mine as(select coins from totals where member=me)
 select jsonb_build_object('coins',(select coins from mine),
 'center_rank',1+(select count(*) from totals where coins>(select coins from mine)),
 'groups',coalesce((select jsonb_object_agg(e.group_id::text,
  1+(select count(*) from public.enrollments peers join totals t on t.member=peers.student_membership_id
     where peers.group_id=e.group_id and t.coins>(select coins from mine))) from public.enrollments e where e.student_membership_id=me),'{}'::jsonb)) into result;
 return result;
end; $$;
create function private.group_rankings(p_group_id bigint) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare org uuid;
begin
 if auth.uid() is null or not private.can_manage_group(p_group_id) then raise exception 'Group staff required' using errcode='42501'; end if;
 select organization_id into org from public.groups where id=p_group_id;
 return (select coalesce(jsonb_object_agg(m.profile_id::text,t.coins),'{}'::jsonb)
 from private.coin_totals(org) t join public.enrollments e on e.student_membership_id=t.member
 join public.memberships m on m.id=t.member where e.group_id=p_group_id);
end; $$;
create function public.group_rankings(p_group_id bigint) returns jsonb language sql security invoker set search_path='' as $$ select private.group_rankings(p_group_id); $$;

-- Explicit API privileges; internal triggers and raw totals are not client callable.
revoke all on function private.sync_group_state(),private.sync_enrollment_state(),private.validate_lesson_schedule() from public,anon,authenticated;
revoke all on function private.set_enrollment_status(bigint,text),public.set_enrollment_status(bigint,text),private.can_work_in_group(bigint),private.can_check_in(bigint),private.can_upload_checkin(text),private.check_in_lesson(bigint,text),public.check_in_lesson(bigint,text),private.can_mark_lesson(bigint),private.group_rankings(bigint),public.group_rankings(bigint) from public,anon;
grant execute on function private.set_enrollment_status(bigint,text),public.set_enrollment_status(bigint,text),private.can_work_in_group(bigint),private.can_check_in(bigint),private.can_upload_checkin(text),private.check_in_lesson(bigint,text),public.check_in_lesson(bigint,text),private.can_mark_lesson(bigint),private.group_rankings(bigint),public.group_rankings(bigint) to authenticated;
