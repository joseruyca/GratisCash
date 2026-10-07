-- GratisCash V12 · métricas económicas privadas
-- Ejecutar después de 007_bidirectional_votes.sql.

begin;

create table if not exists private.opportunity_monetization (
  opportunity_id uuid primary key
    references public.opportunities(id) on delete cascade,
  model text not null default 'none'
    check (model in ('none','affiliate','cpa','cpl','sponsored','direct')),
  network text,
  commission_estimate numeric(12,2)
    check (commission_estimate is null or commission_estimate >= 0),
  currency text not null default 'EUR'
    check (currency ~ '^[A-Z]{3}$'),
  conversions integer not null default 0
    check (conversions >= 0),
  revenue_total numeric(12,2) not null default 0
    check (revenue_total >= 0),
  notes text,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

alter table private.opportunity_monetization enable row level security;
revoke all on private.opportunity_monetization from public,anon,authenticated;

drop policy if exists monetization_no_direct_access
on private.opportunity_monetization;

create policy monetization_no_direct_access
on private.opportunity_monetization
for all
to authenticated
using (false)
with check (false);

create or replace function private.is_current_admin()
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id=auth.uid()
      and p.role='admin'
      and not p.is_suspended
  );
$$;

revoke all on function private.is_current_admin()
from public,anon,authenticated;
grant execute on function private.is_current_admin() to authenticated;

create or replace function private.save_opportunity_monetization(
  p_opportunity_id uuid,
  p_model text,
  p_network text,
  p_commission_estimate numeric,
  p_currency text,
  p_conversions integer,
  p_revenue_total numeric,
  p_notes text
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  normalized_currency text := upper(trim(coalesce(p_currency,'EUR')));
begin
  if not private.is_current_admin() then
    raise exception 'Forbidden';
  end if;

  if p_model not in ('none','affiliate','cpa','cpl','sponsored','direct') then
    raise exception 'Invalid monetization model';
  end if;

  if normalized_currency !~ '^[A-Z]{3}$' then
    raise exception 'Invalid currency';
  end if;

  if p_commission_estimate is not null and p_commission_estimate<0 then
    raise exception 'Invalid commission';
  end if;

  if coalesce(p_conversions,0)<0 or coalesce(p_revenue_total,0)<0 then
    raise exception 'Invalid metrics';
  end if;

  if not exists (
    select 1 from public.opportunities o where o.id=p_opportunity_id
  ) then
    raise exception 'Opportunity not found';
  end if;

  insert into private.opportunity_monetization (
    opportunity_id,model,network,commission_estimate,currency,
    conversions,revenue_total,notes,updated_at,updated_by
  )
  values (
    p_opportunity_id,p_model,
    nullif(trim(coalesce(p_network,'')),''),
    p_commission_estimate,normalized_currency,
    coalesce(p_conversions,0),coalesce(p_revenue_total,0),
    nullif(trim(coalesce(p_notes,'')),''),
    now(),auth.uid()
  )
  on conflict (opportunity_id) do update set
    model=excluded.model,
    network=excluded.network,
    commission_estimate=excluded.commission_estimate,
    currency=excluded.currency,
    conversions=excluded.conversions,
    revenue_total=excluded.revenue_total,
    notes=excluded.notes,
    updated_at=now(),
    updated_by=auth.uid();
end;
$$;

revoke all on function private.save_opportunity_monetization(
  uuid,text,text,numeric,text,integer,numeric,text
) from public,anon,authenticated;
grant execute on function private.save_opportunity_monetization(
  uuid,text,text,numeric,text,integer,numeric,text
) to authenticated;

create or replace function public.save_opportunity_monetization(
  p_opportunity_id uuid,
  p_model text,
  p_network text default null,
  p_commission_estimate numeric default null,
  p_currency text default 'EUR',
  p_conversions integer default 0,
  p_revenue_total numeric default 0,
  p_notes text default null
)
returns void
language sql
security invoker
set search_path=''
as $$
  select private.save_opportunity_monetization(
    p_opportunity_id,p_model,p_network,p_commission_estimate,p_currency,
    p_conversions,p_revenue_total,p_notes
  );
$$;

revoke all on function public.save_opportunity_monetization(
  uuid,text,text,numeric,text,integer,numeric,text
) from public,anon,authenticated;
grant execute on function public.save_opportunity_monetization(
  uuid,text,text,numeric,text,integer,numeric,text
) to authenticated;

drop function if exists public.admin_opportunity_metrics();
drop function if exists private.admin_opportunity_metrics();

create function private.admin_opportunity_metrics()
returns table(
  opportunity_id uuid,
  title text,
  is_sponsored boolean,
  sponsor_name text,
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
    coalesce(sum(c.clicks) filter (where c.day>=current_date-29),0)::bigint,
    coalesce(sum(c.clicks),0)::bigint,
    coalesce(m.model,'none'),m.network,m.commission_estimate,
    coalesce(m.currency,'EUR'),
    coalesce(m.conversions,0),coalesce(m.revenue_total,0)
  from public.opportunities o
  left join private.opportunity_clicks_daily c on c.opportunity_id=o.id
  left join private.opportunity_monetization m on m.opportunity_id=o.id
  where o.status in ('active','expired')
  group by
    o.id,o.title,o.is_sponsored,o.sponsor_name,
    m.model,m.network,m.commission_estimate,m.currency,m.conversions,m.revenue_total
  order by
    coalesce(m.revenue_total,0) desc,
    coalesce(sum(c.clicks) filter (where c.day>=current_date-29),0) desc,
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
