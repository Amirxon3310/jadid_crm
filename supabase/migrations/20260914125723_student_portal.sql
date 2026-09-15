-- Student portal: organization-owned branches and admin-recorded payments.
create table public.branches (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (name = trim(name) and char_length(name) between 1 and 80),
  created_at timestamptz not null default now(),
  primary key (organization_id, name)
);
insert into public.branches(organization_id,name)
select distinct m.organization_id,trim(p.branch) from public.profiles p
join public.memberships m on m.profile_id=p.id
where coalesce(trim(p.branch),'')<>'' on conflict do nothing;
alter table public.branches enable row level security;
grant select,insert on public.branches to authenticated;
create policy branches_read on public.branches for select to authenticated
using ((select private.current_membership_id(organization_id)) is not null);
create policy branches_add on public.branches for insert to authenticated
with check ((select private.has_role(organization_id,array['admin'::public.app_role])));

create table public.payments (
  id bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations(id),
  student_membership_id bigint not null,
  group_id bigint,
  amount bigint not null check (amount > 0 and amount <= 1000000000000),
  paid_on date not null,
  method text not null check (method in ('cash','card','transfer')),
  note text not null default '' check (char_length(note)<=500),
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  foreign key (student_membership_id,organization_id) references public.memberships(id,organization_id),
  foreign key (group_id,organization_id) references public.groups(id,organization_id)
);
create index payments_student_org_date_idx on public.payments(student_membership_id,organization_id,paid_on desc);
create index payments_org_date_idx on public.payments(organization_id,paid_on desc);
create index payments_group_org_idx on public.payments(group_id,organization_id);
create index payments_created_by_idx on public.payments(created_by);
alter table public.payments enable row level security;
grant select,insert on public.payments to authenticated;
create policy payments_read on public.payments for select to authenticated
using ((select private.has_role(organization_id,array['admin'::public.app_role])) or
 (student_membership_id=(select private.current_membership_id(organization_id)) and
  (select private.has_role(organization_id,array['student'::public.app_role]))));
create policy payments_add on public.payments for insert to authenticated
with check ((select private.has_role(organization_id,array['admin'::public.app_role]))
 and created_by=(select auth.uid()) and exists (
   select 1 from public.memberships m where m.id=student_membership_id and m.organization_id=payments.organization_id and m.role='student'
 ) and (group_id is null or exists (
   select 1 from public.enrollments e where e.student_membership_id=payments.student_membership_id and e.group_id=payments.group_id
 )));

-- Completed enrollments remain readable; existing write policies still require
-- an active enrollment for student homework submissions.
create or replace function private.set_enrollment_completed(p_enrollment_id bigint,p_completed boolean)
returns void language plpgsql security definer set search_path='' as $$
declare target public.enrollments;
begin
 select * into target from public.enrollments where id=p_enrollment_id;
 if auth.uid() is null or not found or not private.can_manage_group(target.group_id) then
  raise exception 'Cannot manage this enrollment' using errcode='42501'; end if;
 update public.enrollments set ends_on=case when p_completed then current_date else null end where id=target.id;
end;
$$;
revoke all on function private.set_enrollment_completed(bigint,boolean) from public,anon;
grant execute on function private.set_enrollment_completed(bigint,boolean) to authenticated;
create or replace function public.set_enrollment_completed(p_enrollment_id bigint,p_completed boolean)
returns void language sql security invoker set search_path='' as $$ select private.set_enrollment_completed(p_enrollment_id,p_completed); $$;
revoke all on function public.set_enrollment_completed(bigint,boolean) from public,anon;
grant execute on function public.set_enrollment_completed(bigint,boolean) to authenticated;

-- Return only the caller's totals/ranks; do not expose peer profiles or answers.
create or replace function private.student_rankings(p_organization_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare me bigint; result jsonb;
begin
 me:=private.current_membership_id(p_organization_id);
 if auth.uid() is null or me is null or not private.has_role(p_organization_id,array['student'::public.app_role]) then
  raise exception 'Student membership required' using errcode='42501'; end if;
 with scores as (
   select e.student_membership_id as member,sum(coalesce(r.score,0))::bigint as coins
   from public.assignment_results r join public.enrollments e on e.id=r.enrollment_id
   where r.organization_id=p_organization_id and r.status='accepted'
   group by e.student_membership_id
 ), totals as (
   select m.id,coalesce(s.coins,0) as coins from public.memberships m left join scores s on s.member=m.id
   where m.organization_id=p_organization_id and m.role='student' and m.is_active
 ), mine as (select coins from totals where id=me)
 select jsonb_build_object('coins',(select coins from mine),
   'center_rank',1+(select count(*) from totals where coins>(select coins from mine)),
   'groups',coalesce((select jsonb_object_agg(e.group_id::text,
     1+(select count(*) from public.enrollments peers join totals t on t.id=peers.student_membership_id
        where peers.group_id=e.group_id and t.coins>(select coins from mine)))
     from public.enrollments e where e.student_membership_id=me),'{}'::jsonb)) into result;
 return result;
end;
$$;
revoke all on function private.student_rankings(uuid) from public,anon;
grant execute on function private.student_rankings(uuid) to authenticated;
create or replace function public.student_rankings(p_organization_id uuid)
returns jsonb language sql security invoker set search_path='' as $$ select private.student_rankings(p_organization_id); $$;
revoke all on function public.student_rankings(uuid) from public,anon;
grant execute on function public.student_rankings(uuid) to authenticated;

CREATE OR REPLACE FUNCTION private.can_access_group(p_group_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
    from public.groups g
    join public.memberships me
      on me.organization_id = g.organization_id
     and me.profile_id = (select auth.uid())
     and me.is_active
    where g.id = p_group_id
      and (
        me.role = 'admin'
        or g.teacher_membership_id = me.id
        or exists (
          select 1 from public.enrollments e
          where e.group_id = g.id
            and e.student_membership_id = me.id
        )
      )
  );
$function$
;

CREATE OR REPLACE FUNCTION private.save_profile(p_membership_id bigint, p_profile jsonb, p_outcome text DEFAULT NULL::text, p_role app_role DEFAULT NULL::app_role)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare target public.memberships; admin boolean; edit_personal boolean; can_grade boolean;
 first_text text; last_text text;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into target from public.memberships where id=p_membership_id;
 if not found then raise exception 'Profile not found'; end if;
 perform 1 from public.organizations where id=target.organization_id for update;
 admin := private.has_role(target.organization_id,array['admin'::public.app_role]);
 edit_personal := admin or (target.profile_id=auth.uid() and private.has_role(target.organization_id,array['teacher'::public.app_role]));
 can_grade := admin or exists (
   select 1 from public.groups g join public.enrollments e on e.group_id=g.id
   where e.student_membership_id=target.id and e.ends_on is null
   and g.teacher_membership_id=private.current_membership_id(target.organization_id)
   and private.has_role(target.organization_id,array['teacher'::public.app_role])
 );
 if coalesce(p_profile,'{}'::jsonb) <> '{}'::jsonb then
   if not edit_personal and not (target.profile_id=auth.uid()
      and private.current_membership_id(target.organization_id) is not null
      and p_profile - 'avatar_path' = '{}'::jsonb) then
     raise exception 'Students may only change their avatar' using errcode='42501'; end if;
   if p_profile ? 'branch' and coalesce(p_profile->>'branch','')<>'' and not exists (
     select 1 from public.branches b where b.organization_id=target.organization_id and b.name=p_profile->>'branch'
   ) then raise exception 'Select an existing branch'; end if;
   if p_profile - array['first_name','last_name','age','gender','branch','phone','contact_email','avatar_path'] <> '{}'::jsonb then
     raise exception 'Unsupported profile field';
   end if;
   select coalesce(p_profile->>'first_name',nullif(first_name,''),split_part(full_name,' ',1)),coalesce(p_profile->>'last_name',nullif(last_name,''),case when coalesce(first_name,'')='' then substr(full_name,length(split_part(full_name,' ',1))+2) else '' end)
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
$function$
;

-- Profile updates must pass through the field-aware RPC, including direct REST.
revoke update on public.profiles from authenticated;
drop policy if exists profiles_update_own on public.profiles;

create or replace function private.can_view_membership(p_membership_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships target
    join public.memberships me
      on me.organization_id = target.organization_id
     and me.profile_id = (select auth.uid())
     and me.is_active
    where target.id = p_membership_id
      and (
        target.id = me.id
        or me.role = 'admin'
        or exists (
          select 1
          from public.groups g
          left join public.enrollments e on e.group_id = g.id
          where (g.teacher_membership_id = me.id and e.student_membership_id = target.id)
             or (g.teacher_membership_id = target.id and e.student_membership_id = me.id)
        )
      )
  );
$$;

create or replace function private.can_submit_result(p_assignment bigint,p_enrollment bigint)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.enrollments e
   join public.assignments a on a.group_id=e.group_id and a.organization_id=e.organization_id
   join public.memberships m on m.id=e.student_membership_id
   where e.id=p_enrollment and a.id=p_assignment and e.ends_on is null
     and m.profile_id=(select auth.uid()) and m.is_active and m.role='student');
$$;
revoke all on function private.can_submit_result(bigint,bigint) from public,anon;
grant execute on function private.can_submit_result(bigint,bigint) to authenticated;
drop policy results_insert_student on public.assignment_results;
create policy results_insert_student on public.assignment_results for insert to authenticated
with check (status='submitted' and score is null and reviewed_by is null and reviewed_at is null
 and (select private.can_submit_result(assignment_id,enrollment_id)));
drop policy results_update on public.assignment_results;
create policy results_update on public.assignment_results for update to authenticated
using ((status in ('waiting','submitted','returned') and (select private.can_submit_result(assignment_id,enrollment_id)))
 or exists(select 1 from public.assignments a where a.id=assignment_id and private.can_manage_group(a.group_id)))
with check ((status='submitted' and score is null and reviewed_by is null and reviewed_at is null and (select private.can_submit_result(assignment_id,enrollment_id)))
 or (status in ('accepted','returned') and score between 1 and 5 and exists(select 1 from public.assignments a where a.id=assignment_id and private.can_manage_group(a.group_id))));
create policy results_matching_group on public.assignment_results as restrictive for all to authenticated
using (exists(select 1 from public.enrollments e join public.assignments a on a.group_id=e.group_id where e.id=enrollment_id and a.id=assignment_id))
with check (exists(select 1 from public.enrollments e join public.assignments a on a.group_id=e.group_id where e.id=enrollment_id and a.id=assignment_id));
