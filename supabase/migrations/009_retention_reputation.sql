-- GratisCash V14 · retención y reputación transparente
-- Ejecutar después de 008_private_monetization_metrics.sql.

begin;

create index if not exists opportunity_monetization_updated_by_idx
on private.opportunity_monetization(updated_by);

create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  categories public.opportunity_category[] not null default '{}',
  include_new boolean not null default true,
  include_saved_deadlines boolean not null default true,
  include_submission_updates boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

drop policy if exists notification_preferences_own_select
on public.notification_preferences;
create policy notification_preferences_own_select
on public.notification_preferences
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists notification_preferences_own_insert
on public.notification_preferences;
create policy notification_preferences_own_insert
on public.notification_preferences
for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and (select public.is_active_user())
);

drop policy if exists notification_preferences_own_update
on public.notification_preferences;
create policy notification_preferences_own_update
on public.notification_preferences
for update
to authenticated
using (
  (select auth.uid()) = user_id
  and (select public.is_active_user())
)
with check (
  (select auth.uid()) = user_id
  and (select public.is_active_user())
);

revoke all on public.notification_preferences
from public,anon,authenticated;
grant select,insert,update
on public.notification_preferences
to authenticated;

drop view if exists public.profiles_public;
drop function if exists private.public_profiles_rows();

create function private.public_profiles_rows()
returns table(
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  avatar_path text,
  approved_count integer,
  community_score integer,
  contribution_level text
)
language sql
stable
security definer
set search_path=public
as $$
  with stats as (
    select
      p.id,
      count(o.id) filter (
        where o.status in ('active','expired')
      )::integer as approved_count,
      coalesce(
        sum(o.vote_score) filter (
          where o.status in ('active','expired')
        ),
        0
      )::integer as community_score
    from public.profiles p
    left join public.opportunities o
      on o.author_id=p.id
    where not p.is_suspended
    group by p.id
  )
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    p.avatar_path,
    s.approved_count,
    s.community_score,
    case
      when s.approved_count >= 15
       and s.community_score >= 20
        then 'Aportador destacado'
      when s.approved_count >= 5
        then 'Aportador habitual'
      when s.approved_count >= 1
        then 'Colaborador'
      else 'Nuevo'
    end
  from public.profiles p
  join stats s on s.id=p.id
  where not p.is_suspended;
$$;

revoke all on function private.public_profiles_rows()
from public,anon,authenticated;
grant execute on function private.public_profiles_rows()
to anon,authenticated;

create view public.profiles_public
with (security_invoker=true)
as
select * from private.public_profiles_rows();

grant select on public.profiles_public
to anon,authenticated;

commit;
