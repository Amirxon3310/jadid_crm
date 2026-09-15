-- Restore the requested registration role on older deployments. Preserve the
-- deployment's profile INSERT, including username and any additional fields.
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
