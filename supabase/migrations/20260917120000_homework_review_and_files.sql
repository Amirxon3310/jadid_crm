-- Homework review on a 0–100 scale, several files, and removable homework
-- (2026-09-17).
--
-- 1. A review is a score from 0 to 100: 60 and above is accepted, below is
--    returned. Existing 1–5 marks are carried over as ×20 (5 → 100), and
--    the ranking still counts a homework as score / 20 points, so no pupil's
--    total moves because of the new scale.
-- 2. A homework, a pupil's answer and the teacher's review may each carry
--    several files, kept as a JSON list of {path, name}.
-- 3. Staff may delete a homework; its answers go with it.
--
-- Safe to run whether or not 20260917060000 has been applied first.

-- 1. Scale ---------------------------------------------------------------
alter table public.assignment_results
  drop constraint if exists assignment_results_score_check;
update public.assignment_results set score = score * 20
  where score between 1 and 5;
alter table public.assignment_results
  add constraint assignment_results_score_check check (score between 0 and 100);

drop policy results_update on public.assignment_results;
create policy results_update on public.assignment_results for update to authenticated
using ((status in ('waiting','submitted','returned') and (select private.can_submit_result(assignment_id,enrollment_id)))
 or exists(select 1 from public.assignments a where a.id=assignment_id and private.can_manage_group(a.group_id)))
with check ((status='submitted' and score is null and reviewed_by is null and reviewed_at is null and (select private.can_submit_result(assignment_id,enrollment_id)))
 or (status in ('accepted','returned') and score between 0 and 100 and exists(select 1 from public.assignments a where a.id=assignment_id and private.can_manage_group(a.group_id))));

create or replace function private.coin_totals(p_org uuid) returns table(member bigint,coins bigint)
language sql stable security definer set search_path='' as $$
 with points as (
 select e.student_membership_id as member,round(coalesce(r.score,0)/20.0)::bigint as coins
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

-- 2. Files ---------------------------------------------------------------
alter table public.assignments add column if not exists files jsonb not null default '[]'::jsonb;
alter table public.assignment_results add column if not exists file_path text;
alter table public.assignment_results add column if not exists file_name text;
alter table public.assignment_results add column if not exists files jsonb not null default '[]'::jsonb;
alter table public.assignment_results add column if not exists review_files jsonb not null default '[]'::jsonb;

-- The single file each row could hold so far joins the list.
update public.assignments
  set files = jsonb_build_array(jsonb_build_object('path',file_path,'name',coalesce(file_name,'fayl')))
  where file_path is not null and files = '[]'::jsonb;
update public.assignment_results
  set files = jsonb_build_array(jsonb_build_object('path',file_path,'name',coalesce(file_name,'fayl')))
  where file_path is not null and files = '[]'::jsonb;

-- Any member of the group may upload: staff their task sheets and reviews,
-- pupils their answers.
create or replace function private.can_upload_homework_file(p_path text)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare grp bigint;
begin
 if auth.uid() is null or split_part(p_path,'/',2)!~'^[0-9]+$' then return false; end if;
 grp := split_part(p_path,'/',2)::bigint;
 return private.can_access_group(grp) and exists(
  select 1 from public.groups g where g.id=grp and g.organization_id::text=split_part(p_path,'/',1));
end; $$;

-- 3. Delete --------------------------------------------------------------
grant delete on public.assignments to authenticated;
create policy assignments_delete_staff on public.assignments for delete to authenticated
using ((select private.can_manage_group(group_id)));
