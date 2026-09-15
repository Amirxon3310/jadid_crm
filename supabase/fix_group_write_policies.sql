-- Apply to an existing Jadid database in one transaction.
begin;

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

commit;
