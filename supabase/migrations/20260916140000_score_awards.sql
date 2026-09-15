-- Manual score awards (2026-09-16): on top of the points lessons and homework
-- earn, staff may add a bonus or a penalty, each with a reason, and the
-- pupil's running total counts them.
create table public.score_awards (
  id bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations(id),
  student_membership_id bigint not null,
  group_id bigint,
  amount integer not null check (amount <> 0 and amount between -1000 and 1000),
  note text not null default '' check (char_length(note) <= 300),
  created_by bigint not null,
  created_at timestamptz not null default now(),
  foreign key (student_membership_id,organization_id) references public.memberships(id,organization_id),
  foreign key (group_id,organization_id) references public.groups(id,organization_id),
  foreign key (created_by,organization_id) references public.memberships(id,organization_id)
);
create index score_awards_student_org_idx on public.score_awards(student_membership_id,organization_id);
create index score_awards_group_org_idx on public.score_awards(group_id,organization_id);
create index score_awards_created_by_idx on public.score_awards(created_by);
alter table public.score_awards enable row level security;
grant select,insert on public.score_awards to authenticated;

-- A pupil reads their own history; staff read the groups they manage.
create policy score_awards_read on public.score_awards for select to authenticated
using (
 (select private.has_role(organization_id,array['admin'::public.app_role]))
 or (group_id is not null and (select private.can_manage_group(group_id)))
 or student_membership_id=(select private.current_membership_id(organization_id))
);
create policy score_awards_add on public.score_awards for insert to authenticated
with check (
 created_by=(select private.current_membership_id(organization_id))
 and (
  (select private.has_role(organization_id,array['admin'::public.app_role]))
  or (group_id is not null and (select private.can_manage_group(group_id)))
 )
 and exists (
  select 1 from public.memberships m where m.id=student_membership_id
   and m.organization_id=score_awards.organization_id and m.role='student'
 )
);

-- Totals now carry the awards alongside attendance and accepted homework.
create or replace function private.coin_totals(p_org uuid) returns table(member bigint,coins bigint)
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
 union all
 select s.student_membership_id,s.amount::bigint from public.score_awards s
 where s.organization_id=p_org
 ) select m.id,coalesce(sum(p.coins),0)::bigint from public.memberships m left join points p on p.member=m.id
 where m.organization_id=p_org and m.role='student' and m.is_active group by m.id;
$$;

alter publication supabase_realtime add table public.score_awards;
