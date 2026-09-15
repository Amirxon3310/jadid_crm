create schema if not exists private;

create type public.app_role as enum ('admin', 'teacher', 'student');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(full_name) between 2 and 120),
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug = lower(slug)),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.memberships (
  id bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role public.app_role not null default 'student',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, profile_id),
  unique (id, organization_id)
);

create table public.groups (
  id bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  course text not null,
  teacher_membership_id bigint,
  schedule_text text not null default '',
  room text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (id, organization_id),
  constraint groups_teacher_same_org_fkey
    foreign key (teacher_membership_id, organization_id)
    references public.memberships(id, organization_id)
);

create table public.enrollments (
  id bigint generated always as identity primary key,
  organization_id uuid not null,
  group_id bigint not null,
  student_membership_id bigint not null,
  starts_on date not null default current_date,
  ends_on date,
  created_at timestamptz not null default now(),
  unique (group_id, student_membership_id),
  unique (id, organization_id),
  constraint enrollments_group_same_org_fkey
    foreign key (group_id, organization_id)
    references public.groups(id, organization_id) on delete cascade,
  constraint enrollments_student_same_org_fkey
    foreign key (student_membership_id, organization_id)
    references public.memberships(id, organization_id)
);

create table public.lessons (
  id bigint generated always as identity primary key,
  organization_id uuid not null,
  group_id bigint not null,
  topic text not null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  status text not null default 'planned' check (status in ('planned', 'completed', 'cancelled')),
  created_at timestamptz not null default now(),
  unique (id, organization_id),
  constraint lessons_group_same_org_fkey
    foreign key (group_id, organization_id)
    references public.groups(id, organization_id) on delete cascade
);

create table public.attendance (
  id bigint generated always as identity primary key,
  organization_id uuid not null,
  lesson_id bigint not null,
  enrollment_id bigint not null,
  status text not null check (status in ('present', 'late', 'absent')),
  marked_by bigint not null references public.memberships(id),
  updated_at timestamptz not null default now(),
  unique (lesson_id, enrollment_id),
  constraint attendance_lesson_same_org_fkey
    foreign key (lesson_id, organization_id)
    references public.lessons(id, organization_id) on delete cascade,
  constraint attendance_enrollment_same_org_fkey
    foreign key (enrollment_id, organization_id)
    references public.enrollments(id, organization_id) on delete cascade
);

create table public.assignments (
  id bigint generated always as identity primary key,
  organization_id uuid not null,
  group_id bigint not null,
  title text not null,
  description text not null default '',
  due_at timestamptz not null,
  created_by bigint not null references public.memberships(id),
  created_at timestamptz not null default now(),
  unique (id, organization_id),
  constraint assignments_group_same_org_fkey
    foreign key (group_id, organization_id)
    references public.groups(id, organization_id) on delete cascade
);

create table public.assignment_results (
  id bigint generated always as identity primary key,
  organization_id uuid not null,
  assignment_id bigint not null,
  enrollment_id bigint not null,
  answer text not null default '',
  status text not null default 'waiting' check (status in ('waiting', 'submitted', 'accepted', 'returned')),
  score smallint check (score between 1 and 5),
  comment text not null default '',
  submitted_at timestamptz,
  reviewed_by bigint references public.memberships(id),
  reviewed_at timestamptz,
  unique (assignment_id, enrollment_id),
  constraint results_assignment_same_org_fkey
    foreign key (assignment_id, organization_id)
    references public.assignments(id, organization_id) on delete cascade,
  constraint results_enrollment_same_org_fkey
    foreign key (enrollment_id, organization_id)
    references public.enrollments(id, organization_id) on delete cascade
);

create index memberships_profile_id_idx on public.memberships(profile_id);
create index memberships_organization_role_idx on public.memberships(organization_id, role) where is_active;
create index groups_organization_id_idx on public.groups(organization_id);
create index groups_teacher_membership_id_idx on public.groups(teacher_membership_id);
create index enrollments_group_id_idx on public.enrollments(group_id);
create index enrollments_student_membership_id_idx on public.enrollments(student_membership_id);
create index lessons_group_starts_at_idx on public.lessons(group_id, starts_at desc);
create index attendance_enrollment_id_idx on public.attendance(enrollment_id);
create index assignments_group_due_at_idx on public.assignments(group_id, due_at);
create index assignment_results_enrollment_id_idx on public.assignment_results(enrollment_id);
create index groups_teacher_org_idx on public.groups(teacher_membership_id, organization_id);
create index enrollments_group_org_idx on public.enrollments(group_id, organization_id);
create index enrollments_student_org_idx on public.enrollments(student_membership_id, organization_id);
create index lessons_group_org_idx on public.lessons(group_id, organization_id);
create index attendance_lesson_org_idx on public.attendance(lesson_id, organization_id);
create index attendance_enrollment_org_idx on public.attendance(enrollment_id, organization_id);
create index attendance_marked_by_idx on public.attendance(marked_by);
create index assignments_group_org_idx on public.assignments(group_id, organization_id);
create index assignments_created_by_idx on public.assignments(created_by);
create index results_assignment_org_idx on public.assignment_results(assignment_id, organization_id);
create index results_enrollment_org_idx on public.assignment_results(enrollment_id, organization_id);
create index results_reviewed_by_idx on public.assignment_results(reviewed_by);

insert into public.organizations (slug, name)
values ('jadid', 'Jadid')
on conflict (slug) do nothing;

create or replace function private.current_membership_id(p_organization_id uuid)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select m.id
  from public.memberships m
  where m.organization_id = p_organization_id
    and m.profile_id = (select auth.uid())
    and m.is_active
  limit 1;
$$;

create or replace function private.has_role(p_organization_id uuid, p_roles public.app_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships m
    where m.organization_id = p_organization_id
      and m.profile_id = (select auth.uid())
      and m.is_active
      and m.role = any(p_roles)
  );
$$;

create or replace function private.can_access_group(p_group_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
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
            and e.ends_on is null
        )
      )
  );
$$;

create or replace function private.can_manage_group(p_group_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.groups g
    join public.memberships me
      on me.organization_id = g.organization_id
     and me.profile_id = (select auth.uid())
     and me.is_active
    where g.id = p_group_id
      and (me.role = 'admin' or g.teacher_membership_id = me.id)
  );
$$;

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
          left join public.enrollments e on e.group_id = g.id and e.ends_on is null
          where (g.teacher_membership_id = me.id and e.student_membership_id = target.id)
             or (g.teacher_membership_id = target.id and e.student_membership_id = me.id)
        )
      )
  );
$$;

create or replace function private.can_view_profile(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_profile_id = (select auth.uid())
    or exists (
      select 1 from public.memberships m
      where m.profile_id = p_profile_id
        and (select private.can_view_membership(m.id))
    );
$$;

revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_organization_id uuid;
  v_role public.app_role;
  v_requested_role text;
begin
  -- Registration may choose only these two roles. Later metadata edits do not
  -- update memberships; authorization continues to use the membership table.
  v_requested_role := coalesce(new.raw_user_meta_data ->> 'registration_role', 'student');
  if v_requested_role not in ('student', 'teacher') then
    raise exception 'Invalid registration role' using errcode = '22023';
  end if;
  v_role := v_requested_role::public.app_role;

  if split_part(new.email, '@', 2) = 'login.jadid.invalid' then
    if split_part(new.email, '@', 1) !~ '^[a-z0-9_]{3,32}$' then
      raise exception 'Invalid username' using errcode = '22023';
    end if;
  end if;

  insert into public.profiles (id, full_name, phone)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), split_part(new.email, '@', 1)),
    nullif(trim(new.raw_user_meta_data ->> 'phone'), '')
  );

  select id into v_organization_id
  from public.organizations where slug = 'jadid';
  if v_organization_id is null then
    raise exception 'Organization not configured';
  end if;

  insert into public.memberships (organization_id, profile_id, role)
  values (v_organization_id, new.id, v_role);
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.memberships enable row level security;
alter table public.groups enable row level security;
alter table public.enrollments enable row level security;
alter table public.lessons enable row level security;
alter table public.attendance enable row level security;
alter table public.assignments enable row level security;
alter table public.assignment_results enable row level security;

create policy profiles_select on public.profiles for select to authenticated
using ((select private.can_view_profile(id)));
create policy profiles_update_own on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy organizations_select on public.organizations for select to authenticated
using ((select private.current_membership_id(id)) is not null);
create policy organizations_update_admin on public.organizations for update to authenticated
using ((select private.has_role(id, array['admin'::public.app_role])))
with check ((select private.has_role(id, array['admin'::public.app_role])));

create policy memberships_select on public.memberships for select to authenticated
using ((select private.can_view_membership(id)));
create policy memberships_insert_admin on public.memberships for insert to authenticated
with check ((select private.has_role(organization_id, array['admin'::public.app_role])));
create policy memberships_update_admin on public.memberships for update to authenticated
using ((select private.has_role(organization_id, array['admin'::public.app_role])))
with check ((select private.has_role(organization_id, array['admin'::public.app_role])));

create policy groups_select on public.groups for select to authenticated
using ((select private.can_access_group(id)));
create policy groups_insert_admin on public.groups for insert to authenticated
with check ((select private.has_role(organization_id, array['admin'::public.app_role])));
create policy groups_update_admin on public.groups for update to authenticated
using ((select private.has_role(organization_id, array['admin'::public.app_role])))
with check ((select private.has_role(organization_id, array['admin'::public.app_role])));

create policy enrollments_select on public.enrollments for select to authenticated
using (
  student_membership_id = (select private.current_membership_id(organization_id))
  or (select private.can_manage_group(group_id))
);
create policy enrollments_insert_admin on public.enrollments for insert to authenticated
with check ((select private.has_role(organization_id, array['admin'::public.app_role])));
create policy enrollments_update_admin on public.enrollments for update to authenticated
using ((select private.has_role(organization_id, array['admin'::public.app_role])))
with check ((select private.has_role(organization_id, array['admin'::public.app_role])));

create policy lessons_select on public.lessons for select to authenticated
using ((select private.can_access_group(group_id)));
create policy lessons_insert_staff on public.lessons for insert to authenticated
with check ((select private.can_manage_group(group_id)));
create policy lessons_update_staff on public.lessons for update to authenticated
using ((select private.can_manage_group(group_id)))
with check ((select private.can_manage_group(group_id)));

create policy attendance_select on public.attendance for select to authenticated
using (
  enrollment_id in (
    select e.id from public.enrollments e
    where e.student_membership_id = (select private.current_membership_id(e.organization_id))
  )
  or lesson_id in (
    select l.id from public.lessons l where (select private.can_manage_group(l.group_id))
  )
);
create policy attendance_insert_staff on public.attendance for insert to authenticated
with check (lesson_id in (select l.id from public.lessons l where (select private.can_manage_group(l.group_id))));
create policy attendance_update_staff on public.attendance for update to authenticated
using (lesson_id in (select l.id from public.lessons l where (select private.can_manage_group(l.group_id))))
with check (lesson_id in (select l.id from public.lessons l where (select private.can_manage_group(l.group_id))));

create policy assignments_select on public.assignments for select to authenticated
using ((select private.can_access_group(group_id)));
create policy assignments_insert_staff on public.assignments for insert to authenticated
with check ((select private.can_manage_group(group_id)));
create policy assignments_update_staff on public.assignments for update to authenticated
using ((select private.can_manage_group(group_id)))
with check ((select private.can_manage_group(group_id)));

create policy results_select on public.assignment_results for select to authenticated
using (
  enrollment_id in (
    select e.id from public.enrollments e
    where e.student_membership_id = (select private.current_membership_id(e.organization_id))
  )
  or assignment_id in (
    select a.id from public.assignments a where (select private.can_manage_group(a.group_id))
  )
);
create policy results_insert_student on public.assignment_results for insert to authenticated
with check (
  status = 'submitted' and score is null and reviewed_by is null
  and enrollment_id in (
    select e.id from public.enrollments e
    where e.student_membership_id = (select private.current_membership_id(e.organization_id))
  )
);
create policy results_update on public.assignment_results for update to authenticated
using (
  (
    status in ('waiting', 'submitted', 'returned')
    and enrollment_id in (
      select e.id from public.enrollments e
      where e.student_membership_id = (select private.current_membership_id(e.organization_id))
    )
  )
  or assignment_id in (
      select a.id from public.assignments a where (select private.can_manage_group(a.group_id))
    )
)
with check (
  (
    status = 'submitted' and score is null and reviewed_by is null
    and enrollment_id in (
      select e.id from public.enrollments e
      where e.student_membership_id = (select private.current_membership_id(e.organization_id))
    )
  )
  or (
    status in ('accepted', 'returned') and score between 1 and 5
    and assignment_id in (
      select a.id from public.assignments a where (select private.can_manage_group(a.group_id))
    )
  )
);

grant usage on schema public to authenticated;
grant select on public.profiles, public.organizations, public.memberships, public.groups,
  public.enrollments, public.lessons, public.attendance, public.assignments,
  public.assignment_results to authenticated;
grant update (full_name, phone, updated_at) on public.profiles to authenticated;
grant update (name) on public.organizations to authenticated;
grant insert, update on public.memberships, public.groups, public.enrollments, public.lessons,
  public.attendance, public.assignments to authenticated;
grant insert, update on public.assignment_results to authenticated;
grant usage, select on all sequences in schema public to authenticated;


drop policy if exists assignment_results_insert_same_group on public.assignment_results;
create policy assignment_results_insert_same_group on public.assignment_results
as restrictive for insert to authenticated
with check (
  exists (
    select 1 from public.assignments parent
    join public.enrollments enrollment on enrollment.group_id = parent.group_id
      and enrollment.organization_id = parent.organization_id
    where parent.id = assignment_results.assignment_id
      and enrollment.id = assignment_results.enrollment_id
      and parent.organization_id = assignment_results.organization_id
  )
);

drop policy if exists assignment_results_update_same_group on public.assignment_results;
create policy assignment_results_update_same_group on public.assignment_results
as restrictive for update to authenticated
with check (
  exists (
    select 1 from public.assignments parent
    join public.enrollments enrollment on enrollment.group_id = parent.group_id
      and enrollment.organization_id = parent.organization_id
    where parent.id = assignment_results.assignment_id
      and enrollment.id = assignment_results.enrollment_id
      and parent.organization_id = assignment_results.organization_id
  )
);

drop policy if exists attendance_insert_same_group on public.attendance;
create policy attendance_insert_same_group on public.attendance
as restrictive for insert to authenticated
with check (
  exists (
    select 1 from public.lessons parent
    join public.enrollments enrollment on enrollment.group_id = parent.group_id
      and enrollment.organization_id = parent.organization_id
    where parent.id = attendance.lesson_id
      and enrollment.id = attendance.enrollment_id
      and parent.organization_id = attendance.organization_id
  )
);

drop policy if exists attendance_update_same_group on public.attendance;
create policy attendance_update_same_group on public.attendance
as restrictive for update to authenticated
with check (
  exists (
    select 1 from public.lessons parent
    join public.enrollments enrollment on enrollment.group_id = parent.group_id
      and enrollment.organization_id = parent.organization_id
    where parent.id = attendance.lesson_id
      and enrollment.id = attendance.enrollment_id
      and parent.organization_id = attendance.organization_id
  )
);

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

-- Student portal (2026-09-14).
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
