-- Deleting homework files (2026-09-18).
--
-- The homework-files bucket had policies for upload and read but none for
-- delete, so every removal the app asks for was refused by row security —
-- quietly, because storage answers a refused delete with an empty list. A
-- replaced task sheet and the files of a deleted homework both stayed in the
-- bucket for ever.
--
-- Staff who manage the group may delete its files. A pupil may not: their
-- answer files are not distinguishable by owner in the path, so allowing it
-- would let any pupil in the group delete the teacher's task sheet.

create or replace function private.can_remove_homework_file(p_path text)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare grp bigint;
begin
 if auth.uid() is null or split_part(p_path,'/',2)!~'^[0-9]+$' then return false; end if;
 grp := split_part(p_path,'/',2)::bigint;
 return private.can_manage_group(grp) and exists(
  select 1 from public.groups g where g.id=grp
    and g.organization_id::text=split_part(p_path,'/',1));
end; $$;

revoke all on function private.can_remove_homework_file(text) from public, anon;
grant execute on function private.can_remove_homework_file(text) to authenticated;

drop policy if exists homework_file_delete on storage.objects;
create policy homework_file_delete on storage.objects for delete to authenticated
using (bucket_id='homework-files' and (select private.can_remove_homework_file(name)));
