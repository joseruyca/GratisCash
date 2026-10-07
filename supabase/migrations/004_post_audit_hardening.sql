-- GratisCash V8 · post-audit hardening
-- Captura los cambios validados en producción después de 003_storage_and_security.sql.

begin;

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated;

alter extension pg_trgm set schema extensions;

drop view if exists public.profiles_public;
drop view if exists public.opportunities_public;
drop view if exists public.comments_public;

drop function if exists private.public_profiles_rows();
drop function if exists private.public_opportunities_rows();
drop function if exists private.public_comments_rows();

create function private.public_profiles_rows()
returns table(id uuid, username text, display_name text, avatar_url text)
language sql stable security definer
set search_path = public
as $$
  select p.id, p.username, p.display_name, p.avatar_url
  from public.profiles p
  where not p.is_suspended;
$$;

create function private.public_opportunities_rows()
returns table(
  id uuid, title text, description text, source_name text, source_url text,
  outbound_url text, reward_text text, category public.opportunity_category,
  status public.opportunity_status, effective_status public.opportunity_status,
  starts_at timestamptz, expires_at timestamptz, estimated_minutes integer,
  image_url text, photo_credit text, photo_source_url text, requirements text,
  steps jsonb, is_verified boolean, is_featured boolean, upvote_count integer,
  comment_count integer, created_at timestamptz, updated_at timestamptz,
  published_at timestamptz, last_verified_at timestamptz, author_name text
)
language sql stable security definer
set search_path = public
as $$
  select
    o.id, o.title, o.description, o.source_name, o.source_url,
    coalesce(o.affiliate_url, o.source_url),
    o.reward_text, o.category, o.status,
    case when o.status='active' and o.expires_at is not null and o.expires_at < now()
      then 'expired'::public.opportunity_status else o.status end,
    o.starts_at, o.expires_at, o.estimated_minutes, o.image_url, o.photo_credit,
    o.photo_source_url, o.requirements, o.steps, o.is_verified, o.is_featured,
    o.upvote_count, o.comment_count, o.created_at, o.updated_at,
    o.published_at, o.last_verified_at,
    coalesce(p.display_name, p.username, 'GratisCash')
  from public.opportunities o
  left join public.profiles p on p.id=o.author_id and not p.is_suspended
  where o.status in ('active','expired');
$$;

create function private.public_comments_rows()
returns table(
  id uuid, opportunity_id uuid, author_id uuid, body text,
  created_at timestamptz, author_name text, upvote_count integer
)
language sql stable security definer
set search_path = public
as $$
  select
    c.id, c.opportunity_id, c.author_id, c.body, c.created_at,
    coalesce(p.display_name, p.username, 'Usuario'),
    coalesce((select count(*)::integer from public.comment_votes v where v.comment_id=c.id),0)
  from public.comments c
  join public.profiles p on p.id=c.author_id
  where not c.is_removed
    and not p.is_suspended
    and not exists (
      select 1 from public.blocked_users b
      where b.blocker_id=auth.uid() and b.blocked_id=c.author_id
    );
$$;

revoke all on function private.public_profiles_rows() from public, anon, authenticated;
revoke all on function private.public_opportunities_rows() from public, anon, authenticated;
revoke all on function private.public_comments_rows() from public, anon, authenticated;
grant execute on function private.public_profiles_rows() to anon, authenticated;
grant execute on function private.public_opportunities_rows() to anon, authenticated;
grant execute on function private.public_comments_rows() to anon, authenticated;

create view public.profiles_public
with (security_invoker=true) as select * from private.public_profiles_rows();
create view public.opportunities_public
with (security_invoker=true) as select * from private.public_opportunities_rows();
create view public.comments_public
with (security_invoker=true) as select * from private.public_comments_rows();

revoke all on table public.profiles, public.opportunities, public.comments,
  public.opportunity_votes, public.saved_opportunities, public.comment_votes,
  public.blocked_users, public.reports, public.moderation_actions,
  public.user_moderation_actions, public.moderation_appeals from anon;
grant select on public.profiles_public, public.opportunities_public, public.comments_public to anon, authenticated;

revoke all on function public.limit_comment_submissions() from public, anon, authenticated;
revoke all on function public.limit_opportunity_submissions() from public, anon, authenticated;
revoke all on function public.limit_report_submissions() from public, anon, authenticated;
revoke all on function public.reject_comment_links() from public, anon, authenticated;
revoke all on function public.validate_report_target() from public, anon, authenticated;
revoke all on function public.prepare_opportunity_for_write() from public, anon, authenticated;
revoke all on function public.protect_profile_security_fields() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;

create index if not exists blocked_users_blocked_idx on public.blocked_users(blocked_id);
create index if not exists comment_votes_user_idx on public.comment_votes(user_id);
create index if not exists comments_author_idx on public.comments(author_id);
create index if not exists moderation_actions_actor_idx on public.moderation_actions(actor_id);
create index if not exists moderation_actions_duplicate_idx on public.moderation_actions(duplicate_of);
create index if not exists moderation_appeals_author_idx on public.moderation_appeals(author_id);
create index if not exists moderation_appeals_reviewer_idx on public.moderation_appeals(reviewer_id);
create index if not exists opportunities_author_idx on public.opportunities(author_id);
create index if not exists opportunities_duplicate_idx on public.opportunities(duplicate_of);
create index if not exists opportunities_moderator_idx on public.opportunities(moderator_id);
create index if not exists opportunity_votes_user_idx on public.opportunity_votes(user_id);
create index if not exists reports_reviewer_idx on public.reports(reviewer_id);
create index if not exists saved_opportunities_user_idx on public.saved_opportunities(user_id);
create index if not exists user_moderation_actions_actor_idx on public.user_moderation_actions(actor_id);

drop index if exists public.profiles_username_lower_key;
create unique index if not exists profiles_username_lower_unique_idx
  on public.profiles(lower(username)) where username is not null;

create unique index if not exists reports_one_open_per_target_idx
  on public.reports(reporter_id, target_type, target_id)
  where status in ('open','reviewing');

create or replace function public.normalize_profile_fields()
returns trigger language plpgsql security invoker set search_path=public as $$
begin
  if new.username is not null then new.username := lower(trim(new.username)); end if;
  if new.display_name is not null then new.display_name := nullif(trim(new.display_name), ''); end if;
  return new;
end;
$$;

drop trigger if exists profiles_normalize_fields on public.profiles;
create trigger profiles_normalize_fields
before insert or update of username, display_name on public.profiles
for each row execute function public.normalize_profile_fields();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare
  accepted_version text;
  has_terms_signal boolean;
  has_adult_signal boolean;
  safe_display_name text;
begin
  accepted_version := new.raw_user_meta_data->>'terms_version';
  has_terms_signal :=
    coalesce((new.raw_user_meta_data->>'terms_accepted')::boolean, false)
    or nullif(new.raw_user_meta_data->>'terms_accepted_at', '') is not null;
  has_adult_signal :=
    coalesce((new.raw_user_meta_data->>'adult_confirmed')::boolean, false)
    or nullif(new.raw_user_meta_data->>'adult_confirmed_at', '') is not null;
  safe_display_name := nullif(trim(coalesce(new.raw_user_meta_data->>'display_name','')), '');
  if safe_display_name is null then safe_display_name := 'Usuario'; end if;
  safe_display_name := left(safe_display_name,80);

  insert into public.profiles(
    id, username, display_name, terms_version, terms_accepted_at, adult_confirmed_at
  ) values (
    new.id,
    'user_' || substr(replace(new.id::text,'-',''),1,10),
    safe_display_name,
    case when accepted_version='2026-10-06' and has_terms_signal then '2026-10-06' end,
    case when accepted_version='2026-10-06' and has_terms_signal then now() end,
    case when has_adult_signal then now() end
  );
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;

create or replace function public.has_current_community_consent()
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.profiles p
    where p.id=auth.uid()
      and not p.is_suspended
      and p.terms_version='2026-10-06'
      and p.terms_accepted_at is not null
      and p.adult_confirmed_at is not null
  );
$$;
revoke all on function public.has_current_community_consent() from public, anon, authenticated;
grant execute on function public.has_current_community_consent() to authenticated;

create or replace function public.accept_current_terms()
returns void language plpgsql security definer set search_path=public as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Authentication required'; end if;
  update public.profiles
  set terms_version='2026-10-06',
      terms_accepted_at=now(),
      adult_confirmed_at=coalesce(adult_confirmed_at,now()),
      updated_at=now()
  where id=u and not is_suspended;
  if not found then raise exception 'Profile unavailable'; end if;
end;
$$;
revoke all on function public.accept_current_terms() from public, anon, authenticated;
grant execute on function public.accept_current_terms() to authenticated;

drop policy if exists profiles_update on public.profiles;
drop policy if exists profiles_staff_update on public.profiles;
drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles
for update to authenticated
using (id=(select auth.uid()) and not is_suspended)
with check (id=(select auth.uid()));

create or replace function public.protect_profile_security_fields()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  new.id := old.id;
  new.role := old.role;
  new.is_suspended := old.is_suspended;
  new.suspension_reason := old.suspension_reason;
  new.suspended_at := old.suspended_at;
  new.terms_version := old.terms_version;
  new.terms_accepted_at := old.terms_accepted_at;
  new.adult_confirmed_at := old.adult_confirmed_at;
  return new;
end;
$$;
revoke all on function public.protect_profile_security_fields() from public, anon, authenticated;

alter table public.user_moderation_actions
  drop constraint if exists user_moderation_actions_action_check;
alter table public.user_moderation_actions
  add constraint user_moderation_actions_action_check
  check (action in ('suspended','restored','role_changed'));

create or replace function public.set_user_role(p_user_id uuid, p_role text)
returns void language plpgsql security definer set search_path=public as $$
declare
  caller_role public.app_role;
  current_role public.app_role;
  requested_role public.app_role;
begin
  select role into caller_role from public.profiles where id=auth.uid() and not is_suspended;
  if caller_role <> 'admin' then raise exception 'Forbidden'; end if;
  if p_user_id=auth.uid() then raise exception 'You cannot change your own role'; end if;
  if p_role not in ('user','moderator','admin') then raise exception 'Invalid role'; end if;
  requested_role := p_role::public.app_role;
  select role into current_role from public.profiles where id=p_user_id;
  if current_role is null then raise exception 'User not found'; end if;
  if current_role=requested_role then return; end if;

  update public.profiles set role=requested_role, updated_at=now() where id=p_user_id;
  insert into public.user_moderation_actions(user_id,actor_id,action,reason)
  values(p_user_id,auth.uid(),'role_changed',
    'Role changed from ' || current_role::text || ' to ' || requested_role::text);
end;
$$;
revoke all on function public.set_user_role(uuid,text) from public, anon, authenticated;
grant execute on function public.set_user_role(uuid,text) to authenticated;

create or replace function public.prepare_opportunity_for_write()
returns trigger language plpgsql security definer set search_path=public,extensions as $$
declare existing_id uuid;
begin
  new.source_url_key := public.normalize_opportunity_url(new.source_url);
  if new.status in ('pending','active') then
    perform pg_advisory_xact_lock(hashtext(new.source_url_key));
    select o.id into existing_id
    from public.opportunities o
    where (new.id is null or o.id<>new.id)
      and o.source_url_key=new.source_url_key
      and o.status in ('pending','active')
      and (o.status='pending' or o.expires_at is null or o.expires_at>=now())
      and greatest(
        extensions.similarity(lower(o.title),lower(new.title)),
        extensions.similarity(lower(o.source_name),lower(new.source_name)),
        extensions.similarity(lower(o.title || ' ' || o.source_name),
                              lower(new.title || ' ' || new.source_name))
      ) >= 0.55
    limit 1;
    if existing_id is not null then
      raise exception using errcode='23505', message='OPPORTUNITY_DUPLICATE',
        detail=existing_id::text;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.prepare_opportunity_for_write() from public, anon, authenticated;

create or replace function public.find_duplicate_opportunities(
  p_source_url text, p_title text, p_source_name text
)
returns table(
  id uuid, title text, source_name text, status public.opportunity_status,
  score real, exact_url boolean
)
language sql stable security definer set search_path=public,extensions as $$
  with params as (
    select public.normalize_opportunity_url(p_source_url) normalized_url,
           lower(trim(coalesce(p_title,''))) wanted_title,
           lower(trim(coalesce(p_source_name,''))) wanted_source
  ),
  scored as (
    select o.id,o.title,o.source_name,o.status,
      (o.source_url_key=p.normalized_url) exact_url,
      greatest(
        extensions.similarity(lower(o.title),p.wanted_title),
        extensions.similarity(lower(o.source_name),p.wanted_source),
        extensions.similarity(lower(o.title || ' ' || o.source_name),
                              trim(p.wanted_title || ' ' || p.wanted_source))
      )::real score
    from public.opportunities o cross join params p
    where o.status='active' and (o.expires_at is null or o.expires_at>=now())
  )
  select id,title,source_name,status,score,exact_url from scored
  where exact_url or score>=0.38
  order by exact_url desc, score desc limit 5;
$$;
revoke all on function public.find_duplicate_opportunities(text,text,text) from public, anon, authenticated;
grant execute on function public.find_duplicate_opportunities(text,text,text) to authenticated;

create or replace function public.toggle_opportunity_vote(p_opportunity_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare u uuid := auth.uid();
begin
  if u is null or not public.is_active_user() or not public.has_current_community_consent()
    then raise exception 'Current terms acceptance required'; end if;
  if not exists(
    select 1 from public.opportunities o
    where o.id=p_opportunity_id and o.status='active'
      and (o.expires_at is null or o.expires_at>=now())
  ) then raise exception 'Opportunity not available'; end if;

  if exists(select 1 from public.opportunity_votes where opportunity_id=p_opportunity_id and user_id=u)
  then delete from public.opportunity_votes where opportunity_id=p_opportunity_id and user_id=u;
  else insert into public.opportunity_votes(opportunity_id,user_id) values(p_opportunity_id,u);
  end if;
end;
$$;
revoke all on function public.toggle_opportunity_vote(uuid) from public, anon, authenticated;
grant execute on function public.toggle_opportunity_vote(uuid) to authenticated;

create or replace function public.toggle_saved_opportunity(p_opportunity_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare u uuid := auth.uid();
begin
  if u is null or not public.is_active_user() or not public.has_current_community_consent()
    then raise exception 'Current terms acceptance required'; end if;
  if not exists(select 1 from public.opportunities o
    where o.id=p_opportunity_id and o.status in ('active','expired'))
    then raise exception 'Opportunity not available'; end if;

  if exists(select 1 from public.saved_opportunities where opportunity_id=p_opportunity_id and user_id=u)
  then delete from public.saved_opportunities where opportunity_id=p_opportunity_id and user_id=u;
  else insert into public.saved_opportunities(opportunity_id,user_id) values(p_opportunity_id,u);
  end if;
end;
$$;
revoke all on function public.toggle_saved_opportunity(uuid) from public, anon, authenticated;
grant execute on function public.toggle_saved_opportunity(uuid) to authenticated;

create extension if not exists pg_cron;

create or replace function private.expire_due_opportunities()
returns integer language plpgsql security invoker set search_path=public,private as $$
declare changed_count integer;
begin
  with expired_rows as (
    update public.opportunities
    set status='expired',
        moderated_at=coalesce(moderated_at,now()),
        moderation_reason=coalesce(moderation_reason,'Caducada automáticamente'),
        updated_at=now()
    where status='active' and expires_at is not null and expires_at<now()
    returning id
  ),
  audit_rows as (
    insert into public.moderation_actions(opportunity_id,actor_id,action,reason)
    select id,null,'archived','Caducada automáticamente al alcanzar expires_at'
    from expired_rows returning 1
  )
  select count(*) into changed_count from audit_rows;
  return coalesce(changed_count,0);
end;
$$;
revoke all on function private.expire_due_opportunities() from public, anon, authenticated;

do $$
declare existing_job bigint;
begin
  select jobid into existing_job from cron.job
  where jobname='gratiscash-expire-opportunities' limit 1;
  if existing_job is not null then perform cron.unschedule(existing_job); end if;
end
$$;

select cron.schedule(
  'gratiscash-expire-opportunities',
  '15 * * * *',
  $cron$select private.expire_due_opportunities();$cron$
);

update public.opportunities
set source_url='https://www.revolut.com/es-ES/legal/LaVeladaWelcomeBonusES/',
    last_verified_at=now(),
    updated_at=now()
where id='99999999-9999-4999-8999-999999999999'::uuid;

commit;
