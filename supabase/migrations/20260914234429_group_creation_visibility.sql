-- RETURNING evaluates SELECT policies before a STABLE self-query can see the
-- newly inserted row. Authorize an admin by the row's organization directly.
alter policy groups_select on public.groups using (
 (select private.has_role(organization_id,array['admin'::public.app_role]))
 or (select private.can_access_group(id))
);
-- Publish learning changes; Realtime applies the same SELECT RLS to subscribers.
alter publication supabase_realtime add table public.groups, public.enrollments,
 public.lessons, public.attendance, public.assignments, public.assignment_results, public.lesson_checkins;
