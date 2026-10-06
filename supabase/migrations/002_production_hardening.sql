-- GRATISCASH · ENDURECIMIENTO DE PRODUCCIÓN
-- Duplicados, trazabilidad de moderación, recursos de revisión y consentimiento UGC.
-- Ejecutar después de 001_gratiscash.sql.

create extension if not exists pg_trgm;

alter table public.profiles
  add column if not exists adult_confirmed_at timestamptz,
  add column if not exists suspension_reason text,
  add column if not exists suspended_at timestamptz;

alter table public.profiles
  drop constraint if exists username_reserved;
alter table public.profiles
  add constraint username_reserved check (
    username is null or lower(username) not in (
      'gratiscash', 'gratiscashapp', 'admin', 'administrator', 'moderator',
      'moderador', 'support', 'soporte', 'staff', 'official', 'oficial'
    )
  );

create unique index if not exists profiles_username_lower_unique_idx
on public.profiles(lower(username))
where username is not null;

alter table public.profiles
  drop constraint if exists suspension_reason_length;
alter table public.profiles
  add constraint suspension_reason_length
  check (suspension_reason is null or char_length(suspension_reason) <= 2000);

create or replace function public.protect_profile_security_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.id and not public.is_staff() then
    new.id := old.id;
    new.role := old.role;
    new.is_suspended := old.is_suspended;
    new.suspension_reason := old.suspension_reason;
    new.suspended_at := old.suspended_at;
  end if;
  return new;
end;
$$;

-- El contenido generado por una cuenta debe desaparecer con su cuenta.
-- Las oportunidades editoriales se crean con author_id = null y no se ven afectadas.
alter table public.opportunities
  drop constraint if exists opportunities_author_id_fkey;
alter table public.opportunities
  add constraint opportunities_author_id_fkey
  foreign key (author_id) references public.profiles(id) on delete cascade;

alter table public.opportunities
  add column if not exists source_url_key text,
  add column if not exists moderation_reason text,
  add column if not exists duplicate_of uuid references public.opportunities(id) on delete set null,
  add column if not exists published_at timestamptz,
  add column if not exists last_verified_at timestamptz;

alter table public.opportunities
  drop constraint if exists moderation_reason_length;
alter table public.opportunities
  add constraint moderation_reason_length
  check (moderation_reason is null or char_length(moderation_reason) <= 1200);

create or replace function public.normalize_opportunity_url(raw_url text)
returns text
language sql
immutable
set search_path = ''
as $$
  with base as (
    select lower(split_part(trim(coalesce(raw_url, '')), '#', 1)) as value
  ), stripped as (
    select regexp_replace(
      value,
      '([?&])(utm_[^=&]+|gclid|fbclid|mc_cid|mc_eid)=[^&#]*',
      '\1',
      'gi'
    ) as value
    from base
  ), cleaned as (
    select regexp_replace(
      regexp_replace(
        regexp_replace(value, '\?&', '?', 'g'),
        '&&+',
        '&',
        'g'
      ),
      '[?&/]+$',
      ''
    ) as value
    from stripped
  )
  select value from cleaned;
$$;

update public.opportunities
set source_url_key = public.normalize_opportunity_url(source_url)
where source_url_key is null or source_url_key = '';

create index if not exists opportunities_source_url_key_idx
on public.opportunities(source_url_key);

create index if not exists opportunities_title_trgm_idx
on public.opportunities using gin (lower(title) gin_trgm_ops);

create index if not exists opportunities_source_name_trgm_idx
on public.opportunities using gin (lower(source_name) gin_trgm_ops);

create or replace function public.prepare_opportunity_for_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_id uuid;
begin
  new.source_url_key := public.normalize_opportunity_url(new.source_url);

  if new.status in ('pending', 'active') then
    perform pg_advisory_xact_lock(hashtext(new.source_url_key));

    select o.id
      into existing_id
    from public.opportunities o
    where (new.id is null or o.id <> new.id)
      and o.source_url_key = new.source_url_key
      and o.status in ('pending', 'active')
      and (
        o.status = 'pending'
        or o.expires_at is null
        or o.expires_at >= now()
      )
      and greatest(
        similarity(lower(o.title), lower(new.title)),
        similarity(lower(o.source_name), lower(new.source_name)),
        similarity(
          lower(o.title || ' ' || o.source_name),
          lower(new.title || ' ' || new.source_name)
        )
      ) >= 0.55
    limit 1;

    if existing_id is not null then
      raise exception using
        errcode = '23505',
        message = 'OPPORTUNITY_DUPLICATE',
        detail = existing_id::text;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists opportunities_prepare_write on public.opportunities;
create trigger opportunities_prepare_write
before insert or update of source_url, status, expires_at
on public.opportunities
for each row execute function public.prepare_opportunity_for_write();

-- Solo devuelve oportunidades ya públicas. Las propuestas pendientes de otros usuarios
-- nunca se exponen mediante esta función.
create or replace function public.find_duplicate_opportunities(
  p_source_url text,
  p_title text,
  p_source_name text
)
returns table(
  id uuid,
  title text,
  source_name text,
  status public.opportunity_status,
  score real,
  exact_url boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with params as (
    select
      public.normalize_opportunity_url(p_source_url) as normalized_url,
      lower(trim(coalesce(p_title, ''))) as wanted_title,
      lower(trim(coalesce(p_source_name, ''))) as wanted_source
  ),
  scored as (
    select
      o.id,
      o.title,
      o.source_name,
      o.status,
      (o.source_url_key = p.normalized_url) as exact_url,
      greatest(
        similarity(lower(o.title), p.wanted_title),
        similarity(lower(o.source_name), p.wanted_source),
        similarity(
          lower(o.title || ' ' || o.source_name),
          trim(p.wanted_title || ' ' || p.wanted_source)
        )
      )::real as score
    from public.opportunities o
    cross join params p
    where o.status = 'active'
      and (o.expires_at is null or o.expires_at >= now())
  )
  select s.id, s.title, s.source_name, s.status, s.score, s.exact_url
  from scored s
  where s.exact_url or s.score >= 0.38
  order by s.exact_url desc, s.score desc
  limit 5;
$$;

revoke all on function public.find_duplicate_opportunities(text, text, text)
from public, anon, authenticated;
grant execute on function public.find_duplicate_opportunities(text, text, text)
to authenticated;

create table if not exists public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null check (action in (
    'approved', 'rejected', 'archived', 'marked_duplicate',
    'appeal_reopened', 'appeal_upheld', 'appeal_dismissed'
  )),
  reason text,
  duplicate_of uuid references public.opportunities(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint moderation_action_reason_length
    check (reason is null or char_length(reason) <= 2000)
);

create index if not exists moderation_actions_opportunity_idx
on public.moderation_actions(opportunity_id, created_at desc);

create table if not exists public.user_moderation_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null check (action in ('suspended', 'restored')),
  reason text not null check (char_length(reason) between 8 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists user_moderation_actions_user_idx
on public.user_moderation_actions(user_id, created_at desc);

create table if not exists public.moderation_appeals (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  message text not null check (char_length(message) between 10 and 1200),
  status text not null default 'open' check (status in ('open', 'upheld', 'reopened', 'dismissed')),
  response text check (response is null or char_length(response) between 8 and 2000),
  reviewer_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create unique index if not exists moderation_appeals_one_open_idx
on public.moderation_appeals(opportunity_id, author_id)
where status = 'open';

create index if not exists moderation_appeals_status_idx
on public.moderation_appeals(status, created_at desc);

alter table public.moderation_actions enable row level security;
alter table public.user_moderation_actions enable row level security;
alter table public.moderation_appeals enable row level security;

create policy moderation_actions_staff_read
on public.moderation_actions for select to authenticated
using (public.is_staff());

create policy user_moderation_actions_staff_read
on public.user_moderation_actions for select to authenticated
using (public.is_staff());

create policy moderation_appeals_self_read
on public.moderation_appeals for select to authenticated
using (author_id = auth.uid() or public.is_staff());

create policy moderation_appeals_self_insert
on public.moderation_appeals for insert to authenticated
with check (
  author_id = auth.uid()
  and public.is_active_user()
  and exists(
    select 1
    from public.opportunities o
    where o.id = opportunity_id
      and o.author_id = auth.uid()
      and o.status = 'rejected'
  )
);

create policy moderation_appeals_staff_update
on public.moderation_appeals for update to authenticated
using (public.is_staff())
with check (public.is_staff());

alter table public.reports
  add column if not exists reason_code text not null default 'other';

alter table public.reports
  drop constraint if exists reports_reason_code_valid;
alter table public.reports
  add constraint reports_reason_code_valid check (reason_code in (
    'ended', 'broken_link', 'misleading', 'scam', 'duplicate',
    'spam', 'harassment', 'hate', 'personal_data', 'illegal', 'other'
  ));

-- Una misma persona no puede mantener varias denuncias abiertas sobre el mismo objeto.
create unique index if not exists reports_one_open_per_target_idx
on public.reports(reporter_id, target_type, target_id)
where status in ('open', 'reviewing');

-- Reducimos phishing/spam en comentarios: los enlaces se reservan para la ficha moderada.
create or replace function public.reject_comment_links()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() and new.body ~* '(https?://|www\.)' then
    raise exception 'Links are not allowed in comments';
  end if;
  return new;
end;
$$;

drop trigger if exists comments_reject_links on public.comments;
create trigger comments_reject_links
before insert or update of body on public.comments
for each row execute function public.reject_comment_links();

-- Consentimiento vigente para crear CGU. La versión se cambia de forma explícita
-- cuando se modifican sustancialmente las normas.
create or replace function public.has_current_community_consent()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and not p.is_suspended
      and p.terms_version = '2026-10-05'
      and p.terms_accepted_at is not null
      and p.adult_confirmed_at is not null
  );
$$;

-- Sincroniza los metadatos del registro con el perfil real.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  insert into public.profiles(
    id,
    username,
    display_name,
    terms_version,
    terms_accepted_at,
    adult_confirmed_at
  )
  values(
    new.id,
    'user_' || substr(replace(new.id::text, '-', ''), 1, 10),
    coalesce(new.raw_user_meta_data->>'display_name', 'Usuario'),
    new.raw_user_meta_data->>'terms_version',
    nullif(new.raw_user_meta_data->>'terms_accepted_at', '')::timestamptz,
    nullif(new.raw_user_meta_data->>'adult_confirmed_at', '')::timestamptz
  );
  return new;
end;
$$;

-- Reaplicamos las políticas UGC para exigir consentimiento vigente.
drop policy if exists opportunities_user_insert on public.opportunities;
create policy opportunities_user_insert
on public.opportunities for insert to authenticated
with check (
  public.is_active_user()
  and public.has_current_community_consent()
  and author_id = auth.uid()
  and status = 'pending'
  and affiliate_url is null
  and image_url is null
  and photo_credit is null
  and photo_source_url is null
  and moderator_id is null
  and moderated_at is null
  and not is_featured
  and not is_verified
  and upvote_count = 0
  and comment_count = 0
  and moderation_reason is null
  and duplicate_of is null
);

drop policy if exists comments_insert on public.comments;
create policy comments_insert
on public.comments for insert to authenticated
with check (
  public.is_active_user()
  and public.has_current_community_consent()
  and author_id = auth.uid()
  and not is_removed
  and exists(
    select 1 from public.opportunities o
    where o.id = opportunity_id and o.status in ('active', 'expired')
  )
);

-- Endurecimiento de lectura pública: las tablas base conservan datos internos.
-- El público consume vistas que exponen solo las columnas necesarias.
drop policy if exists profiles_public_read on public.profiles;
drop policy if exists profiles_self_or_staff_read on public.profiles;
create policy profiles_self_or_staff_read
on public.profiles for select to authenticated
using (id = auth.uid() or public.is_staff());

drop policy if exists opportunities_public_read on public.opportunities;
drop policy if exists opportunities_owner_or_staff_read on public.opportunities;
create policy opportunities_owner_or_staff_read
on public.opportunities for select to authenticated
using (author_id = auth.uid() or public.is_staff());

drop policy if exists comments_read on public.comments;
drop policy if exists comments_owner_or_staff_read on public.comments;
create policy comments_owner_or_staff_read
on public.comments for select to authenticated
using (author_id = auth.uid() or public.is_staff());

drop view if exists public.profiles_public;
create view public.profiles_public
with (security_barrier = true)
as
select
  p.id,
  p.username,
  p.display_name,
  p.avatar_url
from public.profiles p
where not p.is_suspended;

drop view if exists public.opportunities_public;
create view public.opportunities_public
with (security_barrier = true)
as
select
  o.id,
  o.title,
  o.description,
  o.source_name,
  o.source_url,
  coalesce(o.affiliate_url, o.source_url) as outbound_url,
  o.reward_text,
  o.category,
  o.status,
  case
    when o.status = 'active' and o.expires_at is not null and o.expires_at < now()
      then 'expired'::public.opportunity_status
    else o.status
  end as effective_status,
  o.starts_at,
  o.expires_at,
  o.estimated_minutes,
  o.image_url,
  o.photo_credit,
  o.photo_source_url,
  o.requirements,
  o.steps,
  o.is_verified,
  o.is_featured,
  o.upvote_count,
  o.comment_count,
  o.created_at,
  o.updated_at,
  o.published_at,
  o.last_verified_at,
  coalesce(p.display_name, p.username, 'GratisCash') as author_name
from public.opportunities o
left join public.profiles p on p.id = o.author_id
where o.status in ('active', 'expired');

drop view if exists public.comments_public;
create view public.comments_public
with (security_barrier = true)
as
select
  c.id,
  c.opportunity_id,
  c.author_id,
  c.body,
  c.created_at,
  coalesce(p.display_name, p.username, 'Usuario') as author_name,
  coalesce((
    select count(*)::integer
    from public.comment_votes v
    where v.comment_id = c.id
  ), 0) as upvote_count
from public.comments c
join public.profiles p on p.id = c.author_id
where not c.is_removed
  and not p.is_suspended
  and not exists(
    select 1
    from public.blocked_users b
    where b.blocker_id = auth.uid() and b.blocked_id = c.author_id
  );

revoke all on public.profiles_public from public;
revoke all on public.opportunities_public from public;
revoke all on public.comments_public from public;
grant select on public.profiles_public to anon, authenticated;
grant select on public.opportunities_public to anon, authenticated;
grant select on public.comments_public to anon, authenticated;

drop view if exists public.profiles_admin;
create view public.profiles_admin
with (security_invoker = true)
as
select
  p.id,
  p.username,
  p.display_name,
  p.role,
  p.is_suspended,
  p.created_at,
  p.updated_at,
  (
    select count(*)::integer
    from public.reports r
    where r.target_type = 'user'
      and r.target_id = p.id
      and r.status in ('open', 'reviewing')
  ) as open_report_count
from public.profiles p;

-- Vista de moderación: calcula el mejor candidato parecido sin bloquear por similitud.
drop view if exists public.opportunities_admin;
create view public.opportunities_admin
with (security_invoker = true)
as
select
  o.*,
  coalesce(p.display_name, p.username, 'Usuario') as author_name,
  dup.id as duplicate_candidate_id,
  dup.title as duplicate_candidate_title,
  dup.exact_url as duplicate_exact_url,
  dup.score as duplicate_score
from public.opportunities o
left join public.profiles p on p.id = o.author_id
left join lateral (
  select
    x.id,
    x.title,
    (x.source_url_key = o.source_url_key) as exact_url,
    greatest(
      similarity(lower(x.title), lower(o.title)),
      similarity(lower(x.source_name), lower(o.source_name)),
      similarity(
        lower(x.title || ' ' || x.source_name),
        lower(o.title || ' ' || o.source_name)
      )
    )::real as score
  from public.opportunities x
  where x.id <> o.id
    and x.status in ('active', 'pending')
    and (x.status = 'pending' or x.expires_at is null or x.expires_at >= now())
  order by score desc
  limit 1
) dup on true;

create or replace view public.reports_admin
with (security_invoker = true)
as
select
  r.*,
  coalesce(reporter.display_name, reporter.username, 'Usuario') as reporter_name,
  case
    when r.target_type = 'opportunity' then (select o.title from public.opportunities o where o.id = r.target_id)
    when r.target_type = 'comment' then (select left(c.body, 160) from public.comments c where c.id = r.target_id)
    when r.target_type = 'user' then (select coalesce(p.display_name, p.username) from public.profiles p where p.id = r.target_id)
    else null
  end as target_label
from public.reports r
left join public.profiles reporter on reporter.id = r.reporter_id;

create or replace view public.moderation_appeals_admin
with (security_invoker = true)
as
select
  a.*,
  o.title as opportunity_title,
  coalesce(p.display_name, p.username, 'Usuario') as author_name
from public.moderation_appeals a
join public.opportunities o on o.id = a.opportunity_id
join public.profiles p on p.id = a.author_id;

-- Sustituye la función antigua por una decisión trazable y motivada.
drop function if exists public.moderate_opportunity(uuid, text);
create or replace function public.moderate_opportunity(
  p_id uuid,
  p_status text,
  p_reason text default null,
  p_duplicate_of uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  action_name text;
begin
  if not public.is_staff() then
    raise exception 'Forbidden';
  end if;

  if p_status not in ('active', 'expired', 'rejected') then
    raise exception 'Invalid status';
  end if;

  if p_status = 'rejected' and char_length(trim(coalesce(p_reason, ''))) < 8 then
    raise exception 'A rejection reason of at least 8 characters is required';
  end if;

  if p_duplicate_of is not null then
    if p_duplicate_of = p_id or not exists(
      select 1 from public.opportunities where id = p_duplicate_of
    ) then
      raise exception 'Invalid duplicate target';
    end if;
    if p_status <> 'rejected' then
      raise exception 'Duplicates must be rejected';
    end if;
  end if;

  update public.opportunities
  set
    status = p_status::public.opportunity_status,
    moderator_id = auth.uid(),
    moderated_at = now(),
    moderation_reason = nullif(trim(coalesce(p_reason, '')), ''),
    duplicate_of = p_duplicate_of,
    is_verified = (p_status = 'active'),
    published_at = case
      when p_status = 'active' then coalesce(published_at, now())
      else published_at
    end,
    last_verified_at = case
      when p_status = 'active' then now()
      else last_verified_at
    end
  where id = p_id;

  if not found then
    raise exception 'Opportunity not found';
  end if;

  action_name := case
    when p_duplicate_of is not null then 'marked_duplicate'
    when p_status = 'active' then 'approved'
    when p_status = 'expired' then 'archived'
    else 'rejected'
  end;

  insert into public.moderation_actions(
    opportunity_id, actor_id, action, reason, duplicate_of
  ) values (
    p_id, auth.uid(), action_name, nullif(trim(coalesce(p_reason, '')), ''), p_duplicate_of
  );
end;
$$;

revoke all on function public.moderate_opportunity(uuid, text, text, uuid)
from public, anon, authenticated;
grant execute on function public.moderate_opportunity(uuid, text, text, uuid)
to authenticated;

create or replace function public.set_user_suspension(
  p_user_id uuid,
  p_suspended boolean,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role public.app_role;
  target_role public.app_role;
begin
  if not public.is_staff() then
    raise exception 'Forbidden';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'You cannot change your own moderation status';
  end if;

  if char_length(trim(coalesce(p_reason, ''))) < 8 then
    raise exception 'A reason of at least 8 characters is required';
  end if;

  select role into caller_role from public.profiles where id = auth.uid();
  select role into target_role from public.profiles where id = p_user_id;

  if target_role is null then
    raise exception 'User not found';
  end if;

  if target_role <> 'user' and caller_role <> 'admin' then
    raise exception 'Only admins can moderate staff accounts';
  end if;

  update public.profiles
  set
    is_suspended = p_suspended,
    suspension_reason = case when p_suspended then trim(p_reason) else null end,
    suspended_at = case when p_suspended then now() else null end,
    updated_at = now()
  where id = p_user_id;

  insert into public.user_moderation_actions(user_id, actor_id, action, reason)
  values(
    p_user_id,
    auth.uid(),
    case when p_suspended then 'suspended' else 'restored' end,
    trim(p_reason)
  );
end;
$$;

revoke all on function public.set_user_suspension(uuid, boolean, text)
from public, anon, authenticated;
grant execute on function public.set_user_suspension(uuid, boolean, text)
to authenticated;

create or replace function public.resolve_moderation_appeal(
  p_id uuid,
  p_decision text,
  p_response text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  row_data public.moderation_appeals%rowtype;
  action_name text;
begin
  if not public.is_staff() then
    raise exception 'Forbidden';
  end if;

  if p_decision not in ('reopen', 'uphold', 'dismiss') then
    raise exception 'Invalid appeal decision';
  end if;

  if char_length(trim(coalesce(p_response, ''))) < 8 then
    raise exception 'A response of at least 8 characters is required';
  end if;

  select * into row_data
  from public.moderation_appeals
  where id = p_id and status = 'open'
  for update;

  if row_data.id is null then
    raise exception 'Appeal not found';
  end if;

  update public.moderation_appeals
  set
    status = case
      when p_decision = 'reopen' then 'reopened'
      when p_decision = 'uphold' then 'upheld'
      else 'dismissed'
    end,
    response = trim(p_response),
    reviewer_id = auth.uid(),
    reviewed_at = now()
  where id = p_id;

  if p_decision = 'reopen' then
    update public.opportunities
    set
      status = 'pending',
      moderator_id = null,
      moderated_at = null,
      moderation_reason = null,
      duplicate_of = null,
      is_verified = false
    where id = row_data.opportunity_id;
  end if;

  action_name := case
    when p_decision = 'reopen' then 'appeal_reopened'
    when p_decision = 'uphold' then 'appeal_upheld'
    else 'appeal_dismissed'
  end;

  insert into public.moderation_actions(
    opportunity_id, actor_id, action, reason
  ) values (
    row_data.opportunity_id, auth.uid(), action_name, trim(p_response)
  );
end;
$$;

revoke all on function public.resolve_moderation_appeal(uuid, text, text)
from public, anon, authenticated;
grant execute on function public.resolve_moderation_appeal(uuid, text, text)
to authenticated;
