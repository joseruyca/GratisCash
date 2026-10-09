-- GratisCash V16 · adquisición agregada
-- Ejecutar después de 009_retention_reputation.sql.

begin;

create table if not exists private.opportunity_acquisition_daily (
  opportunity_id uuid not null
    references public.opportunities(id) on delete cascade,
  day date not null default current_date,
  landing_visits bigint not null default 0 check (landing_visits >= 0),
  shares bigint not null default 0 check (shares >= 0),
  primary key (opportunity_id, day)
);

revoke all on private.opportunity_acquisition_daily
from public,anon,authenticated;

create or replace function private.register_landing_visit(
  p_opportunity_id uuid
)
returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  if not exists (
    select 1 from public.opportunities o
    where o.id=p_opportunity_id
      and o.status in ('active','expired')
  ) then
    return;
  end if;

  insert into private.opportunity_acquisition_daily(
    opportunity_id,day,landing_visits,shares
  )
  values(p_opportunity_id,current_date,1,0)
  on conflict(opportunity_id,day)
  do update set landing_visits=
    private.opportunity_acquisition_daily.landing_visits+1;
end;
$$;

revoke all on function private.register_landing_visit(uuid)
from public,anon,authenticated;
grant execute on function private.register_landing_visit(uuid)
to anon,authenticated;

create or replace function public.register_landing_visit(
  p_opportunity_id uuid
)
returns void
language sql
security invoker
set search_path=''
as $$
  select private.register_landing_visit(p_opportunity_id);
$$;

revoke all on function public.register_landing_visit(uuid)
from public,anon,authenticated;
grant execute on function public.register_landing_visit(uuid)
to anon,authenticated;

create or replace function private.register_opportunity_share(
  p_opportunity_id uuid
)
returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  if not exists (
    select 1 from public.opportunities o
    where o.id=p_opportunity_id
      and o.status in ('active','expired')
  ) then
    return;
  end if;

  insert into private.opportunity_acquisition_daily(
    opportunity_id,day,landing_visits,shares
  )
  values(p_opportunity_id,current_date,0,1)
  on conflict(opportunity_id,day)
  do update set shares=
    private.opportunity_acquisition_daily.shares+1;
end;
$$;

revoke all on function private.register_opportunity_share(uuid)
from public,anon,authenticated;
grant execute on function private.register_opportunity_share(uuid)
to anon,authenticated;

create or replace function public.register_opportunity_share(
  p_opportunity_id uuid
)
returns void
language sql
security invoker
set search_path=''
as $$
  select private.register_opportunity_share(p_opportunity_id);
$$;

revoke all on function public.register_opportunity_share(uuid)
from public,anon,authenticated;
grant execute on function public.register_opportunity_share(uuid)
to anon,authenticated;

drop function if exists public.admin_opportunity_metrics();
drop function if exists private.admin_opportunity_metrics();

create function private.admin_opportunity_metrics()
returns table(
  opportunity_id uuid,
  title text,
  is_sponsored boolean,
  sponsor_name text,
  shares_30d bigint,
  shares_total bigint,
  landing_visits_30d bigint,
  landing_visits_total bigint,
  clicks_30d bigint,
  clicks_total bigint,
  monetization_model text,
  monetization_network text,
  commission_estimate numeric,
  monetization_currency text,
  conversions integer,
  revenue_total numeric
)
language plpgsql
security definer
set search_path=''
as $$
begin
  if not public.is_staff() then
    raise exception 'Forbidden';
  end if;

  return query
  select
    o.id,o.title,o.is_sponsored,o.sponsor_name,
    coalesce((
      select sum(a.shares)
      from private.opportunity_acquisition_daily a
      where a.opportunity_id=o.id and a.day>=current_date-29
    ),0)::bigint,
    coalesce((
      select sum(a.shares)
      from private.opportunity_acquisition_daily a
      where a.opportunity_id=o.id
    ),0)::bigint,
    coalesce((
      select sum(a.landing_visits)
      from private.opportunity_acquisition_daily a
      where a.opportunity_id=o.id and a.day>=current_date-29
    ),0)::bigint,
    coalesce((
      select sum(a.landing_visits)
      from private.opportunity_acquisition_daily a
      where a.opportunity_id=o.id
    ),0)::bigint,
    coalesce((
      select sum(c.clicks)
      from private.opportunity_clicks_daily c
      where c.opportunity_id=o.id and c.day>=current_date-29
    ),0)::bigint,
    coalesce((
      select sum(c.clicks)
      from private.opportunity_clicks_daily c
      where c.opportunity_id=o.id
    ),0)::bigint,
    coalesce(m.model,'none'),
    m.network,
    m.commission_estimate,
    coalesce(m.currency,'EUR'),
    coalesce(m.conversions,0),
    coalesce(m.revenue_total,0)
  from public.opportunities o
  left join private.opportunity_monetization m
    on m.opportunity_id=o.id
  where o.status in ('active','expired')
  order by
    coalesce(m.revenue_total,0) desc,
    coalesce((
      select sum(c.clicks)
      from private.opportunity_clicks_daily c
      where c.opportunity_id=o.id and c.day>=current_date-29
    ),0) desc,
    o.created_at desc;
end;
$$;

revoke all on function private.admin_opportunity_metrics()
from public,anon,authenticated;
grant execute on function private.admin_opportunity_metrics()
to authenticated;

create function public.admin_opportunity_metrics()
returns table(
  opportunity_id uuid,
  title text,
  is_sponsored boolean,
  sponsor_name text,
  shares_30d bigint,
  shares_total bigint,
  landing_visits_30d bigint,
  landing_visits_total bigint,
  clicks_30d bigint,
  clicks_total bigint,
  monetization_model text,
  monetization_network text,
  commission_estimate numeric,
  monetization_currency text,
  conversions integer,
  revenue_total numeric
)
language sql
security invoker
set search_path=''
as $$
  select * from private.admin_opportunity_metrics();
$$;

revoke all on function public.admin_opportunity_metrics()
from public,anon,authenticated;
grant execute on function public.admin_opportunity_metrics()
to authenticated;

commit;
