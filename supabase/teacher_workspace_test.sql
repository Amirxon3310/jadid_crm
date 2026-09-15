-- Real authenticated RLS tests; fixture rows are rolled back.
begin;
do $setup$
declare org uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); t uuid:=gen_random_uuid(); other uuid:=gen_random_uuid(); s uuid:=gen_random_uuid(); actor uuid;
 am bigint; tm bigint; om bigint; sm bigint; g bigint; g2 bigint; e bigint; e2 bigint; l bigint; old_l bigint; foreign_l bigint; task bigint;
begin
 insert into public.organizations(id,slug,name) values(org,'teacher-test-'||org,'Teacher test');
 foreach actor in array array[a,t,other,s] loop
  insert into auth.users(id,email,raw_user_meta_data) values(actor,actor||'@example.invalid','{"full_name":"Teacher Test","registration_role":"student"}');
 end loop;
 insert into public.memberships(organization_id,profile_id,role) values(org,a,'admin') returning id into am;
 insert into public.memberships(organization_id,profile_id,role) values(org,t,'teacher') returning id into tm;
 insert into public.memberships(organization_id,profile_id,role) values(org,other,'teacher') returning id into om;
 insert into public.memberships(organization_id,profile_id,role) values(org,s,'student') returning id into sm;
 insert into public.groups(organization_id,name,course,teacher_membership_id,week_days) values(org,'Own','Course',tm,array[extract(isodow from now() at time zone 'Asia/Tashkent')::integer]) returning id into g;
 insert into public.groups(organization_id,name,course,teacher_membership_id) values(org,'Other','Course',om) returning id into g2;
 insert into public.enrollments(organization_id,group_id,student_membership_id) values(org,g,sm) returning id into e;
 insert into public.enrollments(organization_id,group_id,student_membership_id) values(org,g2,sm) returning id into e2;
 insert into public.lessons(organization_id,group_id,topic,starts_at) values(org,g,'Today',now()) returning id into l;
 insert into public.lessons(organization_id,group_id,topic,starts_at) values(org,g,'Past',now()-interval '7 days') returning id into old_l;
 insert into public.lessons(organization_id,group_id,topic,starts_at) values(org,g2,'Other lesson',now()) returning id into foreign_l;
 insert into public.assignments(organization_id,group_id,lesson_id,title,due_at,created_by) values(org,g,l,'Homework',now()+interval '3 days',tm) returning id into task;
 perform set_config('tw.org',org::text,true); perform set_config('tw.admin',a::text,true); perform set_config('tw.teacher',t::text,true); perform set_config('tw.other',other::text,true); perform set_config('tw.student',s::text,true);
 perform set_config('tw.tm',tm::text,true); perform set_config('tw.om',om::text,true); perform set_config('tw.am',am::text,true); perform set_config('tw.group',g::text,true); perform set_config('tw.g2',g2::text,true);
 perform set_config('tw.e',e::text,true); perform set_config('tw.e2',e2::text,true); perform set_config('tw.lesson',l::text,true); perform set_config('tw.old',old_l::text,true); perform set_config('tw.foreign',foreign_l::text,true); perform set_config('tw.task',task::text,true);
end; $setup$;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('tw.teacher'),true);
do $teacher$
declare org uuid:=current_setting('tw.org')::uuid; g bigint:=current_setting('tw.group')::bigint; l bigint:=current_setting('tw.lesson')::bigint; e bigint:=current_setting('tw.e')::bigint;
 tm bigint:=current_setting('tw.tm')::bigint; blocked boolean; photo text:=auth.uid()||'/'||l||'/selfie.jpg';
begin
 if (select count(*) from public.groups where organization_id=org)<>1 then raise exception 'Teacher sees unassigned group'; end if;
 blocked:=false; begin insert into public.groups(organization_id,name,course,teacher_membership_id) values(org,'Forbidden','Course',tm); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Teacher created group'; end if;
 blocked:=false; begin insert into public.attendance(organization_id,lesson_id,enrollment_id,status,marked_by) values(org,l,e,'present',tm); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Attendance without selfie permitted'; end if;
 blocked:=false; begin perform public.check_in_lesson(current_setting('tw.old')::bigint,photo); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Past day checkin permitted'; end if;
 blocked:=false; begin perform public.check_in_lesson(current_setting('tw.foreign')::bigint,photo); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Other teacher checkin permitted'; end if;
 blocked:=false; begin insert into public.lessons(organization_id,group_id,topic,starts_at) values(org,g,'Wrong weekday',now()+interval '1 day'); exception when raise_exception then blocked:=true; end;
 if not blocked then raise exception 'Wrong schedule accepted'; end if;
 insert into storage.objects(bucket_id,name) values('lesson-checkins',photo);
 perform public.check_in_lesson(l,photo);
 if not exists(select 1 from public.lesson_checkins where lesson_id=l and teacher_membership_id=tm) then raise exception 'Checkin missing'; end if;
 blocked:=false; begin perform public.check_in_lesson(l,photo); exception when unique_violation then blocked:=true; end;
 if not blocked then raise exception 'Duplicate checkin accepted'; end if;
 if private.can_remove_checkin_photo(photo) then raise exception 'Recorded photo removable'; end if;
 insert into public.attendance(organization_id,lesson_id,enrollment_id,status,marked_by) values(org,l,e,'present',tm)
 on conflict(lesson_id,enrollment_id) do update set status=excluded.status,marked_by=excluded.marked_by;
 insert into public.attendance(organization_id,lesson_id,enrollment_id,status,marked_by) values(org,l,e,'late',tm)
 on conflict(lesson_id,enrollment_id) do update set status=excluded.status,marked_by=excluded.marked_by;
 if (public.group_rankings(g)->>current_setting('tw.student'))::int<>10 then raise exception 'Repeated attendance awarded duplicate coins'; end if;
 update public.attendance set status='absent' where lesson_id=l and enrollment_id=e;
 if (public.group_rankings(g)->>current_setting('tw.student'))::int<>0 then raise exception 'Absent correction retained coins'; end if;
 update public.attendance set status='present' where lesson_id=l and enrollment_id=e;
 blocked:=false; begin insert into public.attendance(organization_id,lesson_id,enrollment_id,status,marked_by) values(org,l,current_setting('tw.e2')::bigint,'present',tm); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Cross-group attendance accepted'; end if;
 blocked:=false; begin insert into public.assignments(organization_id,group_id,lesson_id,title,due_at,created_by) values(org,g,current_setting('tw.foreign')::bigint,'Wrong',now(),tm); exception when foreign_key_violation then blocked:=true; end;
 if not blocked then raise exception 'Cross-group lesson homework accepted'; end if;
 perform public.set_enrollment_status(e,'left');
 if not exists(select 1 from public.enrollments where id=e and study_status='left' and ends_on is not null) then raise exception 'Left status missing'; end if;
 perform public.set_enrollment_status(e,'completed');
 perform public.set_enrollment_status(e,'active');
 if not exists(select 1 from public.enrollments where id=e and ends_on is null) then raise exception 'Reactivation failed'; end if;
 update public.lessons set status='completed' where id=l;
end; $teacher$;
select set_config('request.jwt.claim.sub',current_setting('tw.student'),true);
do $student$
declare org uuid:=current_setting('tw.org')::uuid; blocked boolean;
begin
 if exists(select 1 from public.lesson_checkins where organization_id=org) then raise exception 'Student sees teacher selfie'; end if;
 if exists(select 1 from storage.objects where bucket_id='lesson-checkins' and name like current_setting('tw.teacher')||'/%') then raise exception 'Student reads private photo'; end if;
 if (public.student_rankings(org)->>'coins')::int<>10 then raise exception 'Student attendance coins missing'; end if;
 blocked:=false; begin perform public.group_rankings(current_setting('tw.group')::bigint); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Student reads peers private ranking data'; end if;
 blocked:=false; begin perform public.set_enrollment_status(current_setting('tw.e')::bigint,'completed'); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Student graduated self'; end if;
 blocked:=false; begin insert into public.lesson_checkins(organization_id,lesson_id,teacher_membership_id,photo_path) values(org,current_setting('tw.lesson')::bigint,current_setting('tw.tm')::bigint,'fake.jpg'); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Direct checkin insert accepted'; end if;
 if not exists(select 1 from public.lessons where id=current_setting('tw.lesson')::bigint and status='completed') then raise exception 'Student cannot read completed lesson'; end if;
 insert into public.assignment_results(organization_id,assignment_id,enrollment_id,status,answer)
 values(org,current_setting('tw.task')::bigint,current_setting('tw.e')::bigint,'submitted','My answer');
end; $student$;
select set_config('request.jwt.claim.sub',current_setting('tw.teacher'),true);
update public.assignment_results set status='accepted',score=5,reviewed_by=current_setting('tw.tm')::bigint,reviewed_at=now()
 where assignment_id=current_setting('tw.task')::bigint;
select set_config('request.jwt.claim.sub',current_setting('tw.student'),true);
do $coins$ begin
 if (public.student_rankings(current_setting('tw.org')::uuid)->>'coins')::int<>15 then raise exception 'Homework + attendance total wrong'; end if;
end; $coins$;
select set_config('request.jwt.claim.sub',current_setting('tw.admin'),true);
do $admin$
declare g bigint;
begin
 insert into public.groups(organization_id,name,course) values(current_setting('tw.org')::uuid,'Unassigned','Course') returning id into g;
 update public.groups set teacher_membership_id=current_setting('tw.tm')::bigint where id=g;
 if not found then raise exception 'Admin cannot assign teacher'; end if;
 update public.groups set status='frozen' where id=current_setting('tw.group')::bigint;
 if not exists(select 1 from public.groups where id=current_setting('tw.group')::bigint and not is_active) then raise exception 'Group status not synchronized'; end if;
end; $admin$;
select set_config('request.jwt.claim.sub',current_setting('tw.teacher'),true);
do $frozen$ begin
 if private.can_check_in(current_setting('tw.lesson')::bigint) then raise exception 'Frozen checkin allowed'; end if;
 if not exists(select 1 from public.lessons where id=current_setting('tw.lesson')::bigint) then raise exception 'Frozen history lost'; end if;
end; $frozen$;
select set_config('request.jwt.claim.sub',current_setting('tw.student'),true);
do $frozen_student$ begin
 if private.can_submit_result(current_setting('tw.task')::bigint,current_setting('tw.e')::bigint) then raise exception 'Frozen submission allowed'; end if;
end; $frozen_student$;
reset role;
rollback;
select 'teacher workspace RLS, selfie, homework and coin checks passed' as result;
