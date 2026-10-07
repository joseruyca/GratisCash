-- GratisCash V9 · medios seguros y transparencia de afiliación
-- Ejecutar después de 004_post_audit_hardening.sql.

begin;

-- ---------------------------------------------------------------------------
-- Rutas de medios
-- ---------------------------------------------------------------------------

alter table public.opportunities
  add column if not exists image_path text;

alter table public.opportunities
  drop constraint if exists opportunities_image_path_format_check;

alter table public.opportunities
  add constraint opportunities_image_path_format_check
  check (
    image_path is null
    or image_path ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/image[.](jpg|png|webp)$'
  );

alter table public.profiles
  add column if not exists avatar_path text;

alter table public.profiles
  drop constraint if exists profiles_avatar_path_format_check;

alter table public.profiles
  add constraint profiles_avatar_path_format_check
  check (
    avatar_path is null
    or avatar_path ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/avatar$'
  );

-- ---------------------------------------------------------------------------
-- Proyección pública de perfiles
-- ---------------------------------------------------------------------------

drop view if exists public.profiles_public;
drop function if exists private.public_profiles_rows();

create function private.public_profiles_rows()
returns table(
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  avatar_path text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    p.avatar_path
  from public.profiles p
  where not p.is_suspended;
$$;

revoke all on function private.public_profiles_rows()
  from public, anon, authenticated;
grant execute on function private.public_profiles_rows()
  to anon, authenticated;

create view public.profiles_public
with (security_invoker = true)
as
select * from private.public_profiles_rows();

grant select on public.profiles_public to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Proyección pública de oportunidades + transparencia de afiliación
-- ---------------------------------------------------------------------------

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
  is_verified boolean,
  is_featured boolean,
  upvote_count integer,
  comment_count integer,
  created_at timestamptz,
  updated_at timestamptz,
  published_at timestamptz,
  last_verified_at timestamptz,
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
    (o.affiliate_url is not null and o.affiliate_url <> o.source_url) as is_affiliate,
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

grant select on public.opportunities_public to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Vista de moderación con ruta de imagen
-- ---------------------------------------------------------------------------

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
  coalesce(p.display_name, p.username, 'Usuario') as author_name,
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
    (x.source_url_key = o.source_url_key) as exact_url,
    greatest(
      extensions.similarity(lower(x.title), lower(o.title)),
      extensions.similarity(lower(x.source_name), lower(o.source_name)),
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
    extensions.similarity(lower(x.title), lower(o.title)),
    extensions.similarity(lower(x.source_name), lower(o.source_name)),
    extensions.similarity(
      lower(x.title || ' ' || x.source_name),
      lower(o.title || ' ' || o.source_name)
    )
  ) desc
  limit 1
) dup on true;

revoke all on public.opportunities_admin from public, anon;
grant select on public.opportunities_admin to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: una imagen por propuesta pendiente propia
-- ---------------------------------------------------------------------------

drop policy if exists opportunity_images_insert_own on storage.objects;

create policy opportunity_images_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'opportunity-images'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and array_length(storage.foldername(name), 1) = 2
  and (storage.foldername(name))[2]
      ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and storage.filename(name) ~ '^image[.](jpg|png|webp)$'
  and exists (
    select 1
    from public.opportunities o
    where o.id = ((storage.foldername(name))[2])::uuid
      and o.author_id = (select auth.uid())
      and o.status = 'pending'
      and o.image_path is null
  )
  and (select public.is_active_user())
  and (select public.has_current_community_consent())
);

create or replace function public.attach_submission_image(
  p_opportunity_id uuid,
  p_storage_path text
)
returns void
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  u uuid := auth.uid();
  expected_prefix text;
begin
  if u is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_active_user()
     or not public.has_current_community_consent() then
    raise exception 'Current terms acceptance required';
  end if;

  expected_prefix := u::text || '/' || p_opportunity_id::text || '/image.';

  if p_storage_path is null
     or p_storage_path not like expected_prefix || '%'
     or p_storage_path !~* '/image[.](jpg|png|webp)$' then
    raise exception 'Invalid storage path';
  end if;

  if not exists (
    select 1
    from storage.objects s
    where s.bucket_id = 'opportunity-images'
      and s.name = p_storage_path
      and s.owner_id = u::text
  ) then
    raise exception 'Storage object not found';
  end if;

  update public.opportunities o
  set
    image_path = p_storage_path,
    updated_at = now()
  where o.id = p_opportunity_id
    and o.author_id = u
    and o.status = 'pending'
    and o.image_path is null;

  if not found then
    raise exception 'Opportunity is not eligible for image attachment';
  end if;
end;
$$;

revoke all on function public.attach_submission_image(uuid, text)
  from public, anon, authenticated;
grant execute on function public.attach_submission_image(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Avatar: un único objeto por usuario y ruta fijada por RPC
-- ---------------------------------------------------------------------------

create or replace function public.protect_profile_security_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.id := old.id;
  new.role := old.role;
  new.is_suspended := old.is_suspended;
  new.suspension_reason := old.suspension_reason;
  new.suspended_at := old.suspended_at;
  new.terms_version := old.terms_version;
  new.terms_accepted_at := old.terms_accepted_at;
  new.adult_confirmed_at := old.adult_confirmed_at;
  new.avatar_url := old.avatar_url;
  new.avatar_path := old.avatar_path;
  return new;
end;
$$;

revoke all on function public.protect_profile_security_fields()
  from public, anon, authenticated;

create or replace function public.set_my_avatar_path(
  p_storage_path text
)
returns void
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  u uuid := auth.uid();
begin
  if u is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_active_user() then
    raise exception 'Profile unavailable';
  end if;

  if p_storage_path <> u::text || '/avatar' then
    raise exception 'Invalid storage path';
  end if;

  if not exists (
    select 1
    from storage.objects s
    where s.bucket_id = 'avatars'
      and s.name = p_storage_path
      and s.owner_id = u::text
  ) then
    raise exception 'Storage object not found';
  end if;

  update public.profiles
  set
    avatar_path = p_storage_path,
    avatar_url = null,
    updated_at = now()
  where id = u
    and not is_suspended;

  if not found then
    raise exception 'Profile unavailable';
  end if;
end;
$$;

revoke all on function public.set_my_avatar_path(text)
  from public, anon, authenticated;
grant execute on function public.set_my_avatar_path(text)
  to authenticated;

commit;
