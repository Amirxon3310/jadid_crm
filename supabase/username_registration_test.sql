-- Exercise the actual Auth INSERT trigger; all users and metric changes roll back.
begin;
do $test$
declare
  person uuid;
  chosen text;
  blocked boolean := false;
  org uuid := (select id from public.organizations where slug = 'jadid');
begin
  foreach chosen in array array['student', 'teacher'] loop
    person := gen_random_uuid();
    insert into auth.users(id, email, raw_user_meta_data) values (
      person, 'test_' || replace(person::text, '-', '') || '@example.invalid',
      jsonb_build_object('full_name', 'Ali', 'registration_role', chosen)
    );
    if not exists (select 1 from public.memberships where profile_id = person and organization_id = org and role::text = chosen) then
      raise exception 'Wrong registration role for %', chosen;
    end if;
    if (select full_name from public.profiles where id = person) is distinct from 'Ali' then
      raise exception 'Name-only registration failed';
    end if;
    update auth.users set raw_user_meta_data = raw_user_meta_data || '{"registration_role":"admin"}'::jsonb where id = person;
    if not exists (select 1 from public.memberships where profile_id = person and organization_id = org and role::text = chosen) then
      raise exception 'Editable metadata changed membership role';
    end if;
  end loop;
  person := gen_random_uuid();
  begin
    insert into auth.users(id, email, raw_user_meta_data) values (
      person, person::text || '@example.invalid',
      '{"full_name":"Rejected","registration_role":"admin"}'
    );
  exception when invalid_parameter_value then
    blocked := true;
  end;
  if not blocked then raise exception 'Admin registration was allowed'; end if;
end;
$test$;
rollback;
