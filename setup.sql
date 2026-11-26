-- Bang On: play counter and leaderboard. Paste into Supabase > SQL Editor and press Run.

create table if not exists plays (
  id bigint generated always as identity primary key,
  player text not null check (char_length(player) between 8 and 40),
  created_at timestamptz not null default now()
);

create table if not exists scores (
  id bigint generated always as identity primary key,
  name text not null check (char_length(name) between 1 and 12),
  score integer not null check (score between 1 and 5000000),
  wave integer not null check (wave between 1 and 999),
  player text check (char_length(player) <= 40),
  created_at timestamptz not null default now()
);

alter table plays enable row level security;
alter table scores enable row level security;

drop policy if exists "log a play" on plays;
create policy "log a play" on plays for insert to anon with check (true);
drop policy if exists "post a score" on scores;
create policy "post a score" on scores for insert to anon with check (true);
drop policy if exists "read scores" on scores;
create policy "read scores" on scores for select to anon using (true);

grant insert on plays to anon;
grant insert, select on scores to anon;

-- Top 10, best score per device
create or replace view leaderboard with (security_invoker = on) as
select name, score, wave from (
  select distinct on (coalesce(player, name)) name, score, wave
  from scores order by coalesce(player, name), score desc
) t order by score desc limit 10;
grant select on leaderboard to anon;

-- Counts for stats.html
create or replace function game_stats() returns json
language sql security definer set search_path = public as $$
  select json_build_object(
    'games',      (select count(*) from plays),
    'players',    (select count(distinct player) from plays),
    'games_today',(select count(*) from plays
                   where created_at >= (date_trunc('day', now() at time zone 'America/Vancouver') at time zone 'America/Vancouver')),
    'players_today',(select count(distinct player) from plays
                   where created_at >= (date_trunc('day', now() at time zone 'America/Vancouver') at time zone 'America/Vancouver')),
    'games_7d',   (select count(*) from plays where created_at > now() - interval '7 days'),
    'players_7d', (select count(distinct player) from plays where created_at > now() - interval '7 days'),
    'scores',     (select count(*) from scores)
  );
$$;
revoke all on function game_stats() from public;
grant execute on function game_stats() to anon;
