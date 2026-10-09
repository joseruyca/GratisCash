-- GratisCash V17 · atribución agregada por fuente
-- Ejecutar después de 010_acquisition_metrics.sql.

begin;

create table if not exists private.opportunity_acquisition_source_daily (
  opportunity_id uuid not null
    references public.opportunities(id) on delete cascade,
  day date not null default current_date,
  source text not null
    check (source in ('share','search','social','referral','direct')),
  visits bigint not null default 0 check (visits >= 0),
  primary key (opportunity_id,day,source)
);

revoke all on private.opportunity_acquisition_source_daily
from public,anon,authenticated;

create or replace function private.register_landing_source(
  p_opportunity_id uuid,
  p_source text
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  normalized_source text := lower(trim(coalesce(p_source,'direct')));
begin
  if normalized_source not in ('share','search','social','referral','direct') then
    normalized_source := 'direct';
  end if;

  if not exists (
    select 1 from public.opportunities o
    where o.id=p_opportunity_id
      and o.status in ('active','expired')
  ) then
    return;
  end if;

  insert into private.opportunity_acquisition_source_daily(
    opportunity_id,day,source,visits
  )
  values(p_opportunity_id,current_date,normalized_source,1)
  on conflict(opportunity_id,day,source)
  do update set visits=
    private.opportunity_acquisition_source_daily.visits+1;
end;
$$;

revoke all on function private.register_landing_source(uuid,text)
from public,anon,authenticated;
grant execute on function private.register_landing_source(uuid,text)
to anon,authenticated;

create or replace function public.register_landing_source(
  p_opportunity_id uuid,
  p_source text
)
returns void
language sql
security invoker
set search_path=''
as $$
  select private.register_landing_source(p_opportunity_id,p_source);
$$;

revoke all on function public.register_landing_source(uuid,text)
from public,anon,authenticated;
grant execute on function public.register_landing_source(uuid,text)
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
  share_landings_30d bigint,
  search_landings_30d bigint,
  social_landings_30d bigint,
  referral_landings_30d bigint,
  direct_landings_30d bigint,
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
      select sum(s.visits)
      from private.opportunity_acquisition_source_daily s
      where s.opportunity_id=o.id and s.day>=current_date-29 and s.source='share'
    ),0)::bigint,
    coalesce((
      select sum(s.visits)
      from private.opportunity_acquisition_source_daily s
      where s.opportunity_id=o.id and s.day>=current_date-29 and s.source='search'
    ),0)::bigint,
    coalesce((
      select sum(s.visits)
      from private.opportunity_acquisition_source_daily s
      where s.opportunity_id=o.id and s.day>=current_date-29 and s.source='social'
    ),0)::bigint,
    coalesce((
      select sum(s.visits)
      from private.opportunity_acquisition_source_daily s
      where s.opportunity_id=o.id and s.day>=current_date-29 and s.source='referral'
    ),0)::bigint,
    coalesce((
      select sum(s.visits)
      from private.opportunity_acquisition_source_daily s
      where s.opportunity_id=o.id and s.day>=current_date-29 and s.source='direct'
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
  share_landings_30d bigint,
  search_landings_30d bigint,
  social_landings_30d bigint,
  referral_landings_30d bigint,
  direct_landings_30d bigint,
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
