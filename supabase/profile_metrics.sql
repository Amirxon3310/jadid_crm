-- Profile editing, student outcomes, avatar access, and monthly metric history.
alter table public.profiles
  add column if not exists first_name text not null default '',
  add column if not exists last_name text not null default '',
  add column if not exists age smallint check (age between 1 and 120),
  add column if not exists gender text check (gender in ('male','female')),
  add column if not exists branch text not null default '',
  add column if not exists contact_email text not null default '',
  add column if not exists avatar_path text;
update public.profiles set first_name = split_part(full_name,' ',1),
  last_name = trim(substr(full_name, length(split_part(full_name,' ',1))+1))
where first_name = '' and last_name = '';
alter table public.memberships add column if not exists study_status text not null default 'studying'
  check (study_status in ('studying','graduated','unsuccessful'));
alter table public.memberships add column if not exists graduated_at timestamptz;

create or replace function private.can_edit_profile(p_profile uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select (select auth.uid()) = p_profile or exists (
   select 1 from public.memberships target
   where target.profile_id=p_profile and private.has_role(target.organization_id,array['admin'::public.app_role])
 );
$$;
revoke all on function private.can_edit_profile(uuid) from public,anon;
grant execute on function private.can_edit_profile(uuid) to authenticated;

create or replace function private.save_profile(p_membership_id bigint, p_profile jsonb,
  p_outcome text default null, p_role public.app_role default null) returns void
language plpgsql security definer set search_path='' as $$
declare target public.memberships; admin boolean; edit_personal boolean; can_grade boolean;
 first_text text; last_text text;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into target from public.memberships where id=p_membership_id;
 if not found then raise exception 'Profile not found'; end if;
 perform 1 from public.organizations where id=target.organization_id for update;
 admin := private.has_role(target.organization_id,array['admin'::public.app_role]);
 edit_personal := admin or (target.profile_id=auth.uid() and private.current_membership_id(target.organization_id) is not null);
 can_grade := admin or exists (
   select 1 from public.groups g join public.enrollments e on e.group_id=g.id
   where e.student_membership_id=target.id and e.ends_on is null
   and g.teacher_membership_id=private.current_membership_id(target.organization_id)
   and private.has_role(target.organization_id,array['teacher'::public.app_role])
 );
 if coalesce(p_profile,'{}'::jsonb) <> '{}'::jsonb then
   if not edit_personal then raise exception 'Cannot edit this profile' using errcode='42501'; end if;
   if p_profile - array['first_name','last_name','age','gender','branch','phone','contact_email','avatar_path'] <> '{}'::jsonb then
     raise exception 'Unsupported profile field';
   end if;
   select coalesce(p_profile->>'first_name',first_name),coalesce(p_profile->>'last_name',last_name)
     into first_text,last_text from public.profiles where id=target.profile_id;
   if char_length(trim(first_text))<1 or char_length(trim(concat_ws(' ',first_text,last_text))) not between 2 and 120 then
     raise exception 'Invalid name';
   end if;
   if p_profile ? 'avatar_path' and p_profile->>'avatar_path' is not null then
     if split_part(p_profile->>'avatar_path','/',1) <> target.profile_id::text or not exists
       (select 1 from storage.objects where bucket_id='profile-avatars' and name=p_profile->>'avatar_path') then
       raise exception 'Invalid avatar';
     end if;
   end if;
   update public.profiles set first_name=trim(first_text),last_name=trim(last_text),
     full_name=trim(concat_ws(' ',trim(first_text),trim(last_text))),
     age=case when p_profile ? 'age' then (p_profile->>'age')::smallint else age end,
     gender=case when p_profile ? 'gender' then p_profile->>'gender' else gender end,
     branch=coalesce(p_profile->>'branch',branch), phone=coalesce(p_profile->>'phone',phone),
     contact_email=coalesce(p_profile->>'contact_email',contact_email),
     avatar_path=case when p_profile ? 'avatar_path' then p_profile->>'avatar_path' else avatar_path end,
     updated_at=now() where id=target.profile_id;
 end if;
 if p_role is not null and p_role <> target.role then
   if not admin then raise exception 'Admin required' using errcode='42501'; end if;
   if target.role='admin' and not exists (select 1 from public.memberships where organization_id=target.organization_id and role='admin' and is_active and id<>target.id) then
     raise exception 'Last admin cannot be removed'; end if;
   if p_role='student' and exists(select 1 from public.groups where teacher_membership_id=target.id) then
     raise exception 'Reassign teacher groups first'; end if;
   update public.memberships set role=p_role where id=target.id;
 end if;
 if p_outcome is not null then
   if not can_grade or target.role<>'student' or coalesce(p_role,target.role)<>'student' then
     raise exception 'Cannot change student outcome' using errcode='42501'; end if;
   if p_outcome not in ('studying','graduated','unsuccessful') then raise exception 'Invalid outcome'; end if;
   update public.memberships set study_status=p_outcome,
     graduated_at=case when p_outcome='studying' then null else coalesce(graduated_at,now()) end where id=target.id;
 end if;
end;
$$;
revoke all on function private.save_profile(bigint,jsonb,text,public.app_role) from public,anon;
grant execute on function private.save_profile(bigint,jsonb,text,public.app_role) to authenticated;
create or replace function public.save_profile(p_membership_id bigint,p_profile jsonb,
 p_outcome text default null,p_role public.app_role default null) returns void
language sql security invoker set search_path='' as $$
 select private.save_profile(p_membership_id,p_profile,p_outcome,p_role);
$$;
revoke all on function public.save_profile(bigint,jsonb,text,public.app_role) from public,anon;
grant execute on function public.save_profile(bigint,jsonb,text,public.app_role) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-avatars','profile-avatars',false,2097152,array['image/png','image/jpeg'])
on conflict(id) do nothing;
create or replace function private.avatar_profile(p_path text) returns uuid
language sql immutable set search_path='' as $$
 select case when split_part(p_path,'/',1) ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
 then split_part(p_path,'/',1)::uuid else null end;
$$;
revoke all on function private.avatar_profile(text) from public,anon;
grant execute on function private.avatar_profile(text) to authenticated;
create policy profile_avatar_read on storage.objects for select to authenticated
 using(bucket_id='profile-avatars' and private.can_view_profile(private.avatar_profile(name)));
create policy profile_avatar_insert on storage.objects for insert to authenticated
 with check(bucket_id='profile-avatars' and private.can_edit_profile(private.avatar_profile(name)));
create policy profile_avatar_delete on storage.objects for delete to authenticated
 using(bucket_id='profile-avatars' and private.can_edit_profile(private.avatar_profile(name)));

create table private.metric_history (
 id bigint generated always as identity primary key,
 organization_id uuid not null references public.organizations(id) on delete cascade,
 membership_id bigint not null, role public.app_role not null, study_status text not null,
 is_deleted boolean not null default false, captured_at timestamptz not null default now()
);
create index metric_history_lookup on private.metric_history(organization_id,membership_id,captured_at desc,id desc);
create table private.metric_baseline(organization_id uuid primary key references public.organizations(id) on delete cascade,
 started_at timestamptz not null default now());
insert into private.metric_baseline(organization_id) select id from public.organizations;
insert into private.metric_history(organization_id,membership_id,role,study_status)
 select organization_id,id,role,study_status from public.memberships;
revoke all on private.metric_history,private.metric_baseline from public,anon,authenticated;
create or replace function private.record_member_metric() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then
   insert into private.metric_history(organization_id,membership_id,role,study_status,is_deleted)
   values(old.organization_id,old.id,old.role,old.study_status,true); return old;
 end if;
 if tg_op='INSERT' or new.role is distinct from old.role or new.study_status is distinct from old.study_status then
   insert into private.metric_history(organization_id,membership_id,role,study_status)
     values(new.organization_id,new.id,new.role,new.study_status);
 end if;
 return new;
end;
$$;
revoke all on function private.record_member_metric() from public,anon,authenticated;
create trigger membership_metric_changes after insert or update or delete on public.memberships
for each row execute function private.record_member_metric();

create or replace function private.metrics_at(p_org uuid,p_at timestamptz) returns jsonb
language sql stable security definer set search_path='' as $$
 with latest as (
   select distinct on(membership_id) role,study_status,is_deleted from private.metric_history
   where organization_id=p_org and captured_at<=p_at order by membership_id,captured_at desc,id desc
 ), counts as (
   select count(*) filter(where role<>'student') as employees,
   count(*) filter(where role='student') as students,
   count(*) filter(where role='student' and study_status<>'studying') as graduates,
   count(*) filter(where role='student' and study_status='graduated') as successful
   from latest where not is_deleted
 ) select jsonb_build_object('employees',employees,'students',students,'graduates',graduates,
   'success_rate',case when students=0 then 0 else 100.0*successful/students end) from counts;
$$;
revoke all on function private.metrics_at(uuid,timestamptz) from public,anon,authenticated;
create or replace function private.dashboard_metrics(p_organization_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare previous jsonb; baseline timestamptz; org_created timestamptz; cutoff timestamptz := now()-interval '1 month';
begin
 if not private.has_role(p_organization_id,array['admin'::public.app_role]) then
   raise exception 'Admin required' using errcode='42501'; end if;
 select created_at into org_created from public.organizations where id=p_organization_id;
 select started_at into baseline from private.metric_baseline where organization_id=p_organization_id;
 if cutoff < org_created then
   previous := '{"employees":0,"students":0,"graduates":0,"success_rate":0}'::jsonb;
 elsif cutoff >= baseline then previous := private.metrics_at(p_organization_id,cutoff);
 else previous := null; end if;
 return jsonb_build_object('current',private.metrics_at(p_organization_id,now()),'previous',previous,'compared_at',cutoff);
end;
$$;
revoke all on function private.dashboard_metrics(uuid) from public,anon;
grant execute on function private.dashboard_metrics(uuid) to authenticated;
create or replace function public.dashboard_metrics(p_organization_id uuid) returns jsonb
language sql security invoker set search_path='' as $$ select private.dashboard_metrics(p_organization_id); $$;
revoke all on function public.dashboard_metrics(uuid) from public,anon;
grant execute on function public.dashboard_metrics(uuid) to authenticated;
