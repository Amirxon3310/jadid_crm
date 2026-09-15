-- Lesson time window and homework files (2026-09-16): a group now carries a
-- fixed daily lesson start/end time so attendance only opens during that
-- window for a teacher (admin is exempt); homework may carry an attached
-- reference file.
alter table public.groups add column lesson_start_time time;
alter table public.groups add column lesson_end_time time;

alter table public.assignments add column file_path text;
alter table public.assignments add column file_name text;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('homework-files','homework-files',false,10485760,null);

create function private.can_upload_homework_file(p_path text) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare grp bigint;
begin
 if auth.uid() is null or split_part(p_path,'/',2)!~'^[0-9]+$' then return false; end if;
 grp := split_part(p_path,'/',2)::bigint;
 return private.can_manage_group(grp) and exists(
  select 1 from public.groups g where g.id=grp and g.organization_id::text=split_part(p_path,'/',1));
end; $$;
create function private.can_read_homework_file(p_path text) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare grp bigint;
begin
 if auth.uid() is null or split_part(p_path,'/',2)!~'^[0-9]+$' then return false; end if;
 grp := split_part(p_path,'/',2)::bigint;
 return private.can_access_group(grp);
end; $$;
revoke all on function private.can_upload_homework_file(text),private.can_read_homework_file(text) from public,anon;
grant execute on function private.can_upload_homework_file(text),private.can_read_homework_file(text) to authenticated;

create policy homework_file_upload on storage.objects for insert to authenticated
with check(bucket_id='homework-files' and (select private.can_upload_homework_file(name)));
create policy homework_file_read on storage.objects for select to authenticated
using(bucket_id='homework-files' and (select private.can_read_homework_file(name)));
