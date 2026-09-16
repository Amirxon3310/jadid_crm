-- Registration role on older deployments (2026-09-18).
--
-- Adding a teacher sends registration_role='teacher' with the sign-up, and
-- the trigger on auth.users decides the membership from it. A project created
-- before that was added has a trigger that always writes 'student', so an
-- admin adding a teacher gets a pupil — or an error — with nothing in the app
-- able to tell why.
--
-- This is the patch that lived in supabase/username_registration.sql, which
-- was never part of the migration sequence. It does nothing when the trigger
-- is already right, and refuses to touch a trigger it does not recognise.

begin;
do $migration$
declare
  definition text := pg_get_functiondef('public.handle_new_user()'::regprocedure);
  legacy_assignment text := $legacy$if not exists (select 1 from public.memberships where organization_id = v_organization_id) then
    v_role := 'admin';
  else
    v_role := 'student';
  end if;$legacy$;
  role_assignment text := $roles$-- Only these two roles may be chosen during signup. Later metadata
  -- changes cannot change the membership used for authorization.
  if coalesce(new.raw_user_meta_data ->> 'registration_role', 'student') not in ('student', 'teacher') then
    raise exception 'Invalid registration role' using errcode = '22023';
  end if;
  v_role := coalesce(new.raw_user_meta_data ->> 'registration_role', 'student')::public.app_role;$roles$;
begin
  if strpos(definition, role_assignment) > 0 then
    return; -- Already patched.
  end if;
  if strpos(definition, 'v_role := v_requested_role::public.app_role;') > 0
     and strpos(definition, 'v_requested_role not in (''student'', ''teacher'')') > 0 then
    return; -- Fresh installations from schema.sql already support both roles.
  end if;
  if strpos(definition, legacy_assignment) = 0 then
    raise exception 'Unexpected registration trigger; review before replacing it';
  end if;
  execute replace(definition, legacy_assignment, role_assignment);
end;
$migration$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
commit;
