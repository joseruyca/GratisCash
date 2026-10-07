-- GratisCash V10 · monetización transparente
-- Ejecutar después de 005_secure_media_affiliate.sql.

begin;

alter table public.opportunities
  add column if not exists is_sponsored boolean not null default false,
  add column if not exists sponsor_name text,
  add column if not exists sponsored_from timestamptz,
  add column if not exists sponsored_until timestamptz;

alter table public.opportunities
  drop constraint if exists opportunities_sponsorship_check;

alter table public.opportunities
  add constraint opportunities_sponsorship_check
  check (
    (
      not is_sponsored
      and sponsor_name is null
      and sponsored_from is null
      and sponsored_until is null
    )
    or
    (
      is_sponsored
      and nullif(trim(sponsor_name), '') is not null
      and (
        sponsored_until is null
        or sponsored_from is null
        or sponsored_until > sponsored_from
      )
    )
  );

create table if not exists private.opportunity_clicks_daily (
  opportunity_id uuid not null
    references public.opportunities(id) on delete cascade,
  day date not null default current_date,
  clicks bigint not null default 0 check (clicks >= 0),
  primary key (opportunity_id, day)
);

revoke all on private.opportunity_clicks_daily
  from public, anon, authenticated;

create or replace function private.register_outbound_click(
  p_opportunity_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if not exists (
    select 1
    from public.opportunities o
    where o.id = p_opportunity_id
      and o.status in ('active', 'expired')
  ) then
    return;
  end if;

  insert into private.opportunity_clicks_daily(
    opportunity_id,
    day,
    clicks
  )
  values (
    p_opportunity_id,
    current_date,
    1
  )
  on conflict (opportunity_id, day)
  do update
    set clicks = private.opportunity_clicks_daily.clicks + 1;
end;
$$;

revoke all on function private.register_outbound_click(uuid)
  from public, anon, authenticated;
grant execute on function private.register_outbound_click(uuid)
  to anon, authenticated;

create or replace function public.register_outbound_click(
  p_opportunity_id uuid
)
returns void
language sql
security invoker
set search_path = public, private
as $$
  select private.register_outbound_click(p_opportunity_id);
$$;

revoke all on function public.register_outbound_click(uuid)
  from public, anon, authenticated;
grant execute on function public.register_outbound_click(uuid)
  to anon, authenticated;

create or replace function private.admin_opportunity_metrics()
returns table(
  opportunity_id uuid,
  title text,
  is_sponsored boolean,
  sponsor_name text,
  clicks_30d bigint,
  clicks_total bigint
)
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if not public.is_staff() then
    raise exception 'Forbidden';
  end if;

  return query
  select
    o.id,
    o.title,
    o.is_sponsored,
    o.sponsor_name,
    coalesce(
      sum(c.clicks) filter (
        where c.day >= current_date - 29
      ),
      0
    )::bigint,
    coalesce(sum(c.clicks), 0)::bigint
  from public.opportunities o
  left join private.opportunity_clicks_daily c
    on c.opportunity_id = o.id
  where o.status in ('active', 'expired')
  group by
    o.id,
    o.title,
    o.is_sponsored,
    o.sponsor_name
  order by
    o.is_sponsored desc,
    coalesce(
      sum(c.clicks) filter (
        where c.day >= current_date - 29
      ),
      0
    ) desc,
    o.created_at desc;
end;
$$;

revoke all on function private.admin_opportunity_metrics()
  from public, anon, authenticated;
grant execute on function private.admin_opportunity_metrics()
  to authenticated;

create or replace function public.admin_opportunity_metrics()
returns table(
  opportunity_id uuid,
  title text,
  is_sponsored boolean,
  sponsor_name text,
  clicks_30d bigint,
  clicks_total bigint
)
language sql
security invoker
set search_path = public, private
as $$
  select * from private.admin_opportunity_metrics();
$$;

revoke all on function public.admin_opportunity_metrics()
  from public, anon, authenticated;
grant execute on function public.admin_opportunity_metrics()
  to authenticated;

drop view if exists public.opportunities_public;
drop function if exists private.public_opportunities_rows();

create function private.public_opportunities_rows()
returns table(
  id uuid,
  title text,
  description text,
  source_name text,
  source_url text,
  outbound_url text,
  is_affiliate boolean,
  is_sponsored boolean,
  sponsor_name text,
  reward_text text,
  category public.opportunity_category,
  status public.opportunity_status,
  effective_status public.opportunity_status,
  starts_at timestamptz,
  expires_at timestamptz,
  estimated_minutes integer,
  image_url text,
  image_path text,
  photo_credit text,
  photo_source_url text,
  requirements text,
  steps jsonb,
  is_featured boolean,
  upvote_count integer,
  comment_count integer,
  created_at timestamptz,
  updated_at timestamptz,
  published_at timestamptz,
  author_name text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    o.id,
    o.title,
    o.description,
    o.source_name,
    o.source_url,
    coalesce(o.affiliate_url, o.source_url) as outbound_url,
    (
      o.affiliate_url is not null
      and o.affiliate_url <> o.source_url
    ) as is_affiliate,
    (
      o.is_sponsored
      and (
        o.sponsored_from is null
        or o.sponsored_from <= now()
      )
      and (
        o.sponsored_until is null
        or o.sponsored_until >= now()
      )
    ) as is_sponsored,
    case
      when o.is_sponsored
       and (
         o.sponsored_from is null
         or o.sponsored_from <= now()
       )
       and (
         o.sponsored_until is null
         or o.sponsored_until >= now()
       )
      then o.sponsor_name
      else null
    end as sponsor_name,
    o.reward_text,
    o.category,
    o.status,
    case
      when o.status = 'active'
       and o.expires_at is not null
       and o.expires_at < now()
      then 'expired'::public.opportunity_status
      else o.status
    end as effective_status,
    o.starts_at,
    o.expires_at,
    o.estimated_minutes,
    o.image_url,
    o.image_path,
    o.photo_credit,
    o.photo_source_url,
    o.requirements,
    o.steps,
    o.is_featured,
    o.upvote_count,
    o.comment_count,
    o.created_at,
    o.updated_at,
    o.published_at,
    coalesce(
      p.display_name,
      p.username,
      'GratisCash'
    ) as author_name
  from public.opportunities o
  left join public.profiles p
    on p.id = o.author_id
   and not p.is_suspended
  where o.status in ('active', 'expired');
$$;

revoke all on function private.public_opportunities_rows()
  from public, anon, authenticated;
grant execute on function private.public_opportunities_rows()
  to anon, authenticated;

create view public.opportunities_public
with (security_invoker = true)
as
select * from private.public_opportunities_rows();

grant select on public.opportunities_public
  to anon, authenticated;

drop view if exists public.opportunities_admin;

create view public.opportunities_admin
with (security_invoker = true)
as
select
  o.id,
  o.author_id,
  o.title,
  o.description,
  o.source_name,
  o.source_url,
  o.affiliate_url,
  o.reward_text,
  o.category,
  o.status,
  o.starts_at,
  o.expires_at,
  o.estimated_minutes,
  o.image_url,
  o.image_path,
  o.photo_credit,
  o.photo_source_url,
  o.requirements,
  o.steps,
  o.is_verified,
  o.is_featured,
  o.is_sponsored,
  o.sponsor_name,
  o.sponsored_from,
  o.sponsored_until,
  o.moderator_id,
  o.moderated_at,
  o.upvote_count,
  o.comment_count,
  o.created_at,
  o.updated_at,
  o.source_url_key,
  o.moderation_reason,
  o.duplicate_of,
  o.published_at,
  o.last_verified_at,
  coalesce(
    p.display_name,
    p.username,
    'Usuario'
  ) as author_name,
  dup.id as duplicate_candidate_id,
  dup.title as duplicate_candidate_title,
  dup.exact_url as duplicate_exact_url,
  dup.score as duplicate_score
from public.opportunities o
left join public.profiles p
  on p.id = o.author_id
left join lateral (
  select
    x.id,
    x.title,
    (
      x.source_url_key = o.source_url_key
    ) as exact_url,
    greatest(
      extensions.similarity(
        lower(x.title),
        lower(o.title)
      ),
      extensions.similarity(
        lower(x.source_name),
        lower(o.source_name)
      ),
      extensions.similarity(
        lower(x.title || ' ' || x.source_name),
        lower(o.title || ' ' || o.source_name)
      )
    )::real as score
  from public.opportunities x
  where x.id <> o.id
    and x.status in ('active', 'pending')
    and (
      x.status = 'pending'
      or x.expires_at is null
      or x.expires_at >= now()
    )
  order by greatest(
    extensions.similarity(
      lower(x.title),
      lower(o.title)
    ),
    extensions.similarity(
      lower(x.source_name),
      lower(o.source_name)
    ),
    extensions.similarity(
      lower(x.title || ' ' || x.source_name),
      lower(o.title || ' ' || o.source_name)
    )
  ) desc
  limit 1
) dup on true;

revoke all on public.opportunities_admin
  from public, anon;
grant select on public.opportunities_admin
  to authenticated;

commit;
