-- GratisCash V11 · valoración positiva/negativa segura
-- Ejecutar después de 006_monetization_foundation.sql.

begin;

alter table public.opportunity_votes
  add column if not exists value smallint not null default 1,
  add column if not exists updated_at timestamptz not null default now();

alter table public.opportunity_votes
  drop constraint if exists opportunity_votes_value_check;

alter table public.opportunity_votes
  add constraint opportunity_votes_value_check
  check (value in (-1, 1));

alter table public.opportunities
  add column if not exists downvote_count integer not null default 0,
  add column if not exists vote_score integer not null default 0;

-- Los votos existentes eran positivos en el sistema anterior.
update public.opportunity_votes
set value=1
where value is null or value not in (-1,1);

update public.opportunities o
set
  upvote_count = coalesce(v.upvotes,0),
  downvote_count = coalesce(v.downvotes,0),
  vote_score = coalesce(v.score,0)
from (
  select
    opportunity_id,
    count(*) filter (where value=1)::integer as upvotes,
    count(*) filter (where value=-1)::integer as downvotes,
    coalesce(sum(value),0)::integer as score
  from public.opportunity_votes
  group by opportunity_id
) v
where o.id=v.opportunity_id;

update public.opportunities o
set upvote_count=0,downvote_count=0,vote_score=0
where not exists (
  select 1
  from public.opportunity_votes v
  where v.opportunity_id=o.id
);

create or replace function public.refresh_opportunity_vote_count()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  target_id uuid := coalesce(new.opportunity_id,old.opportunity_id);
begin
  update public.opportunities o
  set
    upvote_count=(
      select count(*)::integer
      from public.opportunity_votes v
      where v.opportunity_id=target_id and v.value=1
    ),
    downvote_count=(
      select count(*)::integer
      from public.opportunity_votes v
      where v.opportunity_id=target_id and v.value=-1
    ),
    vote_score=(
      select coalesce(sum(v.value),0)::integer
      from public.opportunity_votes v
      where v.opportunity_id=target_id
    )
  where o.id=target_id;

  return coalesce(new,old);
end;
$$;

drop trigger if exists opportunity_votes_refresh_count
on public.opportunity_votes;

create trigger opportunity_votes_refresh_count
after insert or update of value or delete
on public.opportunity_votes
for each row
execute function public.refresh_opportunity_vote_count();

create or replace function private.set_opportunity_vote(
  p_opportunity_id uuid,
  p_value smallint
)
returns smallint
language plpgsql
security definer
set search_path=public
as $$
declare
  u uuid := auth.uid();
  current_value smallint;
  opportunity_author uuid;
begin
  if u is null
     or not public.is_active_user()
     or not public.has_current_community_consent() then
    raise exception 'Current terms acceptance required';
  end if;

  if p_value not in (-1,1) then
    raise exception 'Invalid vote';
  end if;

  select o.author_id
  into opportunity_author
  from public.opportunities o
  where o.id=p_opportunity_id
    and o.status='active'
    and (o.expires_at is null or o.expires_at>=now());

  if not found then
    raise exception 'Opportunity not available';
  end if;

  if opportunity_author=u then
    raise exception 'Authors cannot vote on their own opportunity';
  end if;

  select v.value
  into current_value
  from public.opportunity_votes v
  where v.opportunity_id=p_opportunity_id
    and v.user_id=u;

  if current_value=p_value then
    delete from public.opportunity_votes
    where opportunity_id=p_opportunity_id
      and user_id=u;
    return 0;
  end if;

  insert into public.opportunity_votes(
    opportunity_id,user_id,value,created_at,updated_at
  )
  values(
    p_opportunity_id,u,p_value,now(),now()
  )
  on conflict (opportunity_id,user_id)
  do update set
    value=excluded.value,
    updated_at=now();

  return p_value;
end;
$$;

revoke all on function private.set_opportunity_vote(uuid,smallint)
from public,anon,authenticated;
grant execute on function private.set_opportunity_vote(uuid,smallint)
to authenticated;

create or replace function public.set_opportunity_vote(
  p_opportunity_id uuid,
  p_value smallint
)
returns smallint
language sql
security invoker
set search_path=public,private
as $$
  select private.set_opportunity_vote(p_opportunity_id,p_value);
$$;

revoke all on function public.set_opportunity_vote(uuid,smallint)
from public,anon,authenticated;
grant execute on function public.set_opportunity_vote(uuid,smallint)
to authenticated;

create or replace function public.toggle_opportunity_vote(
  p_opportunity_id uuid
)
returns void
language sql
security invoker
set search_path=public,private
as $$
  select private.set_opportunity_vote(p_opportunity_id,1::smallint);
$$;

revoke all on function public.toggle_opportunity_vote(uuid)
from public,anon,authenticated;
grant execute on function public.toggle_opportunity_vote(uuid)
to authenticated;

drop policy if exists votes_own on public.opportunity_votes;
create policy votes_own
on public.opportunity_votes
for all
to authenticated
using (
  user_id=(select auth.uid())
  and (select public.is_active_user())
)
with check (
  user_id=(select auth.uid())
  and (select public.is_active_user())
  and value in (-1,1)
);

revoke insert,update,delete,truncate,references,trigger
on public.opportunity_votes
from authenticated;
grant select on public.opportunity_votes to authenticated;

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
  downvote_count integer,
  vote_score integer,
  comment_count integer,
  created_at timestamptz,
  updated_at timestamptz,
  published_at timestamptz,
  author_name text
)
language sql
stable
security definer
set search_path=public
as $$
  select
    o.id,o.title,o.description,o.source_name,o.source_url,
    coalesce(o.affiliate_url,o.source_url),
    (o.affiliate_url is not null and o.affiliate_url<>o.source_url),
    (
      o.is_sponsored
      and (o.sponsored_from is null or o.sponsored_from<=now())
      and (o.sponsored_until is null or o.sponsored_until>=now())
    ),
    case
      when o.is_sponsored
       and (o.sponsored_from is null or o.sponsored_from<=now())
       and (o.sponsored_until is null or o.sponsored_until>=now())
      then o.sponsor_name
      else null
    end,
    o.reward_text,o.category,o.status,
    case
      when o.status='active'
       and o.expires_at is not null
       and o.expires_at<now()
      then 'expired'::public.opportunity_status
      else o.status
    end,
    o.starts_at,o.expires_at,o.estimated_minutes,
    o.image_url,o.image_path,o.photo_credit,o.photo_source_url,
    o.requirements,o.steps,o.is_featured,
    o.upvote_count,o.downvote_count,o.vote_score,o.comment_count,
    o.created_at,o.updated_at,o.published_at,
    coalesce(p.display_name,p.username,'GratisCash')
  from public.opportunities o
  left join public.profiles p
    on p.id=o.author_id and not p.is_suspended
  where o.status in ('active','expired');
$$;

revoke all on function private.public_opportunities_rows()
from public,anon,authenticated;
grant execute on function private.public_opportunities_rows()
to anon,authenticated;

create view public.opportunities_public
with (security_invoker=true)
as select * from private.public_opportunities_rows();

grant select on public.opportunities_public to anon,authenticated;

drop view if exists public.opportunities_admin;

create view public.opportunities_admin
with (security_invoker=true)
as
select
  o.id,o.author_id,o.title,o.description,o.source_name,o.source_url,
  o.affiliate_url,o.reward_text,o.category,o.status,o.starts_at,o.expires_at,
  o.estimated_minutes,o.image_url,o.image_path,o.photo_credit,o.photo_source_url,
  o.requirements,o.steps,o.is_verified,o.is_featured,o.is_sponsored,o.sponsor_name,
  o.sponsored_from,o.sponsored_until,o.moderator_id,o.moderated_at,
  o.upvote_count,o.downvote_count,o.vote_score,o.comment_count,
  o.created_at,o.updated_at,o.source_url_key,o.moderation_reason,o.duplicate_of,
  o.published_at,o.last_verified_at,
  coalesce(p.display_name,p.username,'Usuario') as author_name,
  dup.id as duplicate_candidate_id,
  dup.title as duplicate_candidate_title,
  dup.exact_url as duplicate_exact_url,
  dup.score as duplicate_score
from public.opportunities o
left join public.profiles p on p.id=o.author_id
left join lateral (
  select
    x.id,
    x.title,
    (x.source_url_key=o.source_url_key) as exact_url,
    greatest(
      extensions.similarity(lower(x.title),lower(o.title)),
      extensions.similarity(lower(x.source_name),lower(o.source_name)),
      extensions.similarity(
        lower(x.title || ' ' || x.source_name),
        lower(o.title || ' ' || o.source_name)
      )
    )::real as score
  from public.opportunities x
  where x.id<>o.id
    and x.status in ('active','pending')
    and (x.status='pending' or x.expires_at is null or x.expires_at>=now())
  order by greatest(
    extensions.similarity(lower(x.title),lower(o.title)),
    extensions.similarity(lower(x.source_name),lower(o.source_name)),
    extensions.similarity(
      lower(x.title || ' ' || x.source_name),
      lower(o.title || ' ' || o.source_name)
    )
  ) desc
  limit 1
) dup on true;

revoke all on public.opportunities_admin from public,anon;
grant select on public.opportunities_admin to authenticated;

commit;
