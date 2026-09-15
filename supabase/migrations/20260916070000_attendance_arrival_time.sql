-- Attendance arrival time (2026-09-16): a teacher may optionally record
-- what time a present/late student actually arrived, alongside status.
alter table public.attendance add column arrived_at time;
