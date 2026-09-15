-- Tests real RLS and RPCs under authenticated identities. No fixtures persist.
begin;
do $setup$
declare org uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); t uuid:=gen_random_uuid(); s uuid:=gen_random_uuid(); peer uuid:=gen_random_uuid(); high uuid:=gen_random_uuid();
 actor uuid; am bigint; tm bigint; sm bigint; pm bigint; hm bigint; g bigint; g2 bigint; e bigint; ep bigint; eh bigint; task bigint; task2 bigint; task3 bigint; lesson bigint;
begin
 insert into public.organizations(id,slug,name) values(org,'portal-'||org::text,'Portal test');
 foreach actor in array array[a,t,s,peer,high] loop
  insert into auth.users(id,email,raw_user_meta_data) values(actor,actor::text||'@example.invalid','{"full_name":"Portal Test","registration_role":"student"}');
 end loop;
 insert into public.memberships(organization_id,profile_id,role) values(org,a,'admin') returning id into am;
 insert into public.memberships(organization_id,profile_id,role) values(org,t,'teacher') returning id into tm;
 insert into public.memberships(organization_id,profile_id,role) values(org,s,'student') returning id into sm;
 insert into public.memberships(organization_id,profile_id,role) values(org,peer,'student') returning id into pm;
 insert into public.memberships(organization_id,profile_id,role) values(org,high,'student') returning id into hm;
 insert into public.groups(organization_id,name,course,teacher_membership_id) values(org,'One','Course',tm) returning id into g;
 insert into public.groups(organization_id,name,course,teacher_membership_id) values(org,'Two','Course',tm) returning id into g2;
 insert into public.enrollments(organization_id,group_id,student_membership_id) values(org,g,sm) returning id into e;
 insert into public.enrollments(organization_id,group_id,student_membership_id) values(org,g,pm) returning id into ep;
 insert into public.enrollments(organization_id,group_id,student_membership_id) values(org,g2,hm) returning id into eh;
 insert into public.assignments(organization_id,group_id,title,due_at,created_by) values(org,g,'Task',now(),tm) returning id into task;
 insert into public.assignments(organization_id,group_id,title,due_at,created_by) values(org,g2,'Task 2',now(),tm) returning id into task2;
 insert into public.assignments(organization_id,group_id,title,due_at,created_by) values(org,g2,'Task 3',now(),tm) returning id into task3;
 insert into public.assignment_results(organization_id,assignment_id,enrollment_id,status,score) values(org,task,e,'accepted',5),(org,task,ep,'accepted',5),(org,task2,eh,'accepted',5),(org,task3,eh,'accepted',5);
 insert into public.lessons(organization_id,group_id,topic,starts_at) values(org,g,'Lesson',now()) returning id into lesson;
 insert into public.payments(organization_id,student_membership_id,amount,paid_on,method,created_by) values(org,sm,500000,current_date,'cash',a),(org,pm,700000,current_date,'card',a);
 insert into public.branches(organization_id,name) values(org,'Main');
 insert into storage.objects(bucket_id,name) values('profile-avatars',s::text||'/portal.png');
 perform set_config('portal.org',org::text,true); perform set_config('portal.admin',a::text,true); perform set_config('portal.teacher',t::text,true); perform set_config('portal.student',s::text,true);
 perform set_config('portal.sm',sm::text,true); perform set_config('portal.tm',tm::text,true); perform set_config('portal.pm',pm::text,true); perform set_config('portal.group',g::text,true); perform set_config('portal.enrollment',e::text,true);
 perform set_config('portal.lesson',lesson::text,true); perform set_config('portal.task2',task2::text,true);
end;
$setup$;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('portal.student'),true);
do $student$
declare org uuid:=current_setting('portal.org')::uuid; me bigint:=current_setting('portal.sm')::bigint; stats jsonb; blocked boolean;
begin
 if (select count(*) from public.payments where organization_id=org)<>1 then raise exception 'Student sees another payment'; end if;
 if (select sum(amount) from public.payments where organization_id=org)<>500000 then raise exception 'Wrong own payment'; end if;
 stats:=public.student_rankings(org);
 if (stats->>'coins')::int<>5 or (stats->>'center_rank')::int<>2 or (stats->'groups'->>current_setting('portal.group'))::int<>1 then raise exception 'Wrong ranking: %',stats; end if;
 blocked:=false; begin perform public.save_profile(me,'{"first_name":"Forbidden"}'); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Student changed name'; end if;
 blocked:=false; begin perform public.save_profile(me,'{"branch":"Main"}'); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Student changed branch'; end if;
 blocked:=false; begin update public.profiles set phone='Forbidden' where id=auth.uid(); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Direct profile REST update permitted'; end if;
 perform public.save_profile(me,jsonb_build_object('avatar_path',auth.uid()::text||'/portal.png'));
 if (select avatar_path from public.profiles where id=auth.uid())<>auth.uid()::text||'/portal.png' then raise exception 'Own avatar failed'; end if;
 blocked:=false; begin perform public.save_profile(current_setting('portal.pm')::bigint,'{"avatar_path":null}'); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Changed peer avatar'; end if;
 blocked:=false; begin insert into public.payments(organization_id,student_membership_id,amount,paid_on,method) values(org,me,1,current_date,'cash'); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Student inserted payment'; end if;
 blocked:=false; begin insert into public.branches(organization_id,name) values(org,'Forbidden'); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Student added branch'; end if;
 blocked:=false; begin perform public.set_enrollment_completed(current_setting('portal.enrollment')::bigint,true); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Student graduated self'; end if;
 blocked:=false; begin insert into public.assignment_results(organization_id,assignment_id,enrollment_id,status) values(org,current_setting('portal.task2')::bigint,current_setting('portal.enrollment')::bigint,'submitted'); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Student submitted to another group'; end if;
end;
$student$;
select set_config('request.jwt.claim.sub',current_setting('portal.teacher'),true);
do $teacher$
begin
 if exists(select 1 from public.payments where organization_id=current_setting('portal.org')::uuid) then raise exception 'Teacher sees payments'; end if;
 perform public.save_profile(current_setting('portal.tm')::bigint,'{"first_name":"Teacher","branch":"Main"}');
 perform public.set_enrollment_completed(current_setting('portal.enrollment')::bigint,true);
 update public.lessons set status='completed' where id=current_setting('portal.lesson')::bigint;
 if not found then raise exception 'Teacher cannot complete own lesson'; end if;
end;
$teacher$;
select set_config('request.jwt.claim.sub',current_setting('portal.student'),true);
do $history$
begin
 if not exists(select 1 from public.groups where id=current_setting('portal.group')::bigint) then raise exception 'Completed group disappeared'; end if;
 if not exists(select 1 from public.lessons where id=current_setting('portal.lesson')::bigint and status='completed') then raise exception 'Completed lesson not visible'; end if;
 if private.can_submit_result(current_setting('portal.task2')::bigint,current_setting('portal.enrollment')::bigint) then raise exception 'Completed enrollment can submit'; end if;
end;
$history$;
select set_config('request.jwt.claim.sub',current_setting('portal.admin'),true);
do $admin$
declare org uuid:=current_setting('portal.org')::uuid; blocked boolean:=false;
begin
 if (select count(*) from public.payments where organization_id=org)<>2 then raise exception 'Admin cannot see all payments'; end if;
 insert into public.branches(organization_id,name) values(org,'New branch');
 perform public.save_profile(current_setting('portal.sm')::bigint,'{"first_name":"Admin edited","branch":"New branch"}');
 begin perform public.save_profile(current_setting('portal.sm')::bigint,'{"branch":"Unknown"}'); exception when raise_exception then blocked:=true; end;
 if not blocked then raise exception 'Unknown branch accepted'; end if;
 insert into public.payments(organization_id,student_membership_id,group_id,amount,paid_on,method) values(org,current_setting('portal.sm')::bigint,current_setting('portal.group')::bigint,250000,current_date,'transfer');
 if (select count(*) from public.payments where organization_id=org)<>3 then raise exception 'Admin payment failed'; end if;
end;
$admin$;
reset role;
rollback;
