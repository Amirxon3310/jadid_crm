-- Classmates' results (2026-09-17).
--
-- group_classmates returned a pupil's total only, so on the rating board a
-- classmate's homework, attendance, reward and penalty columns all read zero
-- while the total was right — the parts are counted from rows a pupil cannot
-- read. The function now returns those parts as well, worked out on the
-- server, so the board reads the same for everyone.
--
-- Safe to run whether or not 20260917200000 has been applied first.

create or replace function public.group_classmates(p_group_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid; me bigint;
begin
  select organization_id into org from public.groups where id=p_group_id;
  if org is null then raise exception 'Guruh topilmadi' using errcode='42501'; end if;
  me := private.current_membership_id(org);
  if auth.uid() is null or me is null then
    raise exception 'Kirish kerak' using errcode='42501';
  end if;
  -- The caller must belong to the group: enrolled in it, or its staff.
  if not exists (
        select 1 from public.enrollments e
        where e.group_id = p_group_id and e.student_membership_id = me)
     and not private.can_manage_group(p_group_id) then
    raise exception 'Bu guruhda emassiz' using errcode='42501';
  end if;
  return (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'profile_id', m.profile_id,
          'membership_id', m.id,
          'enrollment_id', e.id,
          'full_name', p.full_name,
          'avatar_path', p.avatar_path,
          'study_status', e.study_status,
          'points', coalesce(t.coins, 0),
          -- The same parts the board shows for the pupil themselves.
          'homework_points', coalesce((
            select sum(round(coalesce(r.score,0)/20.0))
            from public.assignment_results r
            join public.assignments a on a.id = r.assignment_id
            where r.enrollment_id = e.id and r.status = 'accepted'
              and a.group_id = p_group_id), 0),
          'attendance_points', coalesce((
            select count(*) * 10
            from public.attendance att
            join public.lessons l on l.id = att.lesson_id
            where att.enrollment_id = e.id and att.status in ('present','late')
              and l.group_id = p_group_id and l.status <> 'cancelled'), 0),
          'reward_points', coalesce((
            select sum(s.amount) from public.score_awards s
            where s.student_membership_id = m.id and s.group_id = p_group_id
              and s.amount > 0), 0),
          'penalty_points', coalesce((
            select sum(s.amount) from public.score_awards s
            where s.student_membership_id = m.id and s.group_id = p_group_id
              and s.amount < 0), 0)
        )
        order by coalesce(t.coins, 0) desc, p.full_name
      ),
      '[]'::jsonb
    )
    from public.enrollments e
    join public.memberships m on m.id = e.student_membership_id
    join public.profiles p on p.id = m.profile_id
    left join private.coin_totals(org) t on t.member = m.id
    where e.group_id = p_group_id and m.role = 'student'
  );
end; $$;

revoke all on function public.group_classmates(bigint) from public, anon;
grant execute on function public.group_classmates(bigint) to authenticated;
