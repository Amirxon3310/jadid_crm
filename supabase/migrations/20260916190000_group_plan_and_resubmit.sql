-- Group plan and homework resubmission (2026-09-16).
--
-- 1. A group carries its plan: how many lessons it runs for and the day it
--    started. Progress is then "lessons held out of the plan", which is what
--    a pupil sees on their dashboard.
-- 2. A returned homework says whether the pupil may send it again. The
--    teacher decides that when returning it, and the rule is enforced here
--    as well as in the app.

alter table public.groups
  add column if not exists total_lessons int
  check (total_lessons is null or total_lessons between 1 and 500);
alter table public.groups add column if not exists starts_on date;

alter table public.assignment_results
  add column if not exists resubmit_allowed boolean not null default true;

-- A pupil may still edit a waiting or submitted answer; a returned one only
-- when the teacher allowed it.
drop policy results_update on public.assignment_results;
create policy results_update on public.assignment_results for update to authenticated
using (
  (
    status in ('waiting','submitted','returned')
    and (status <> 'returned' or resubmit_allowed)
    and (select private.can_submit_result(assignment_id,enrollment_id))
  )
  or exists(
    select 1 from public.assignments a
    where a.id=assignment_id and private.can_manage_group(a.group_id)
  )
)
with check (
  (
    status='submitted' and score is null and reviewed_by is null
    and reviewed_at is null
    and (select private.can_submit_result(assignment_id,enrollment_id))
  )
  or (
    status in ('accepted','returned') and score between 0 and 100
    and exists(
      select 1 from public.assignments a
      where a.id=assignment_id and private.can_manage_group(a.group_id)
    )
  )
);
