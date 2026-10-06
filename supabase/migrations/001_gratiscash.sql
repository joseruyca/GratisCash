-- GRATISCASH · ESQUEMA INICIAL SEGURO
-- Diseñado para un proyecto Supabase NUEVO. Ejecutar una sola vez como propietario.
-- No contiene service_role ni secretos de frontend.

create extension if not exists pgcrypto;

create type public.app_role as enum ('user', 'moderator', 'admin');
create type public.opportunity_status as enum ('draft', 'pending', 'active', 'expired', 'rejected');
create type public.opportunity_category as enum ('money', 'freeProduct', 'cashback', 'bonus', 'mission');
create type public.report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text,
  avatar_url text,
  role public.app_role not null default 'user',
  is_suspended boolean not null default false,
  terms_version text,
  terms_accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint username_length check (username is null or char_length(username) between 3 and 32),
  constraint username_chars check (username is null or username ~ '^[A-Za-z0-9_.]+$'),
  constraint display_name_length check (display_name is null or char_length(display_name) <= 80),
  constraint avatar_https check (avatar_url is null or avatar_url = '' or avatar_url ~ '^https://')
);

create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  author_id uuid references public.profiles(id) on delete set null,
  title text not null,
  description text not null,
  source_name text not null,
  source_url text not null,
  affiliate_url text,
  reward_text text not null,
  category public.opportunity_category not null,
  status public.opportunity_status not null default 'pending',
  starts_at timestamptz,
  expires_at timestamptz,
  estimated_minutes integer,
  image_url text,
  photo_credit text,
  photo_source_url text,
  requirements text,
  steps jsonb not null default '[]'::jsonb,
  is_verified boolean not null default false,
  is_featured boolean not null default false,
  moderator_id uuid references public.profiles(id) on delete set null,
  moderated_at timestamptz,
  upvote_count integer not null default 0,
  comment_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint title_length check (char_length(title) between 4 and 120),
  constraint description_length check (char_length(description) between 4 and 3000),
  constraint source_name_length check (char_length(source_name) between 2 and 120),
  constraint reward_length check (char_length(reward_text) between 1 and 80),
  constraint minutes_positive check (estimated_minutes is null or estimated_minutes between 1 and 10080),
  constraint source_https check (source_url ~ '^https://'),
  constraint affiliate_https check (affiliate_url is null or affiliate_url = '' or affiliate_url ~ '^https://'),
  constraint image_https check (image_url is null or image_url = '' or image_url ~ '^https://'),
  constraint photo_source_https check (photo_source_url is null or photo_source_url = '' or photo_source_url ~ '^https://'),
  constraint photo_credit_length check (photo_credit is null or char_length(photo_credit) <= 180),
  constraint requirements_length check (requirements is null or char_length(requirements) <= 2000),
  constraint nonnegative_counts check (upvote_count >= 0 and comment_count >= 0)
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  is_removed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint comment_length check (char_length(body) between 2 and 1200)
);

create table public.opportunity_votes (
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (opportunity_id, user_id)
);

create table public.saved_opportunities (
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (opportunity_id, user_id)
);

create table public.comment_votes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

create table public.blocked_users (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint cannot_block_self check (blocker_id <> blocked_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('opportunity', 'comment', 'user')),
  target_id uuid not null,
  reason text not null check (char_length(reason) between 2 and 500),
  status public.report_status not null default 'open',
  reviewer_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create index opportunities_status_created_idx on public.opportunities(status, created_at desc);
create index opportunities_expires_idx on public.opportunities(expires_at);
create index opportunities_category_idx on public.opportunities(category);
create index comments_opportunity_idx on public.comments(opportunity_id, created_at desc);
create index reports_status_idx on public.reports(status, created_at desc);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch
before update on public.profiles
for each row execute function public.touch_updated_at();

create trigger opportunities_touch
before update on public.opportunities
for each row execute function public.touch_updated_at();

create trigger comments_touch
before update on public.comments
for each row execute function public.touch_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  insert into public.profiles(id, username, display_name, terms_version, terms_accepted_at)
  values(
    new.id,
    'user_' || substr(replace(new.id::text, '-', ''), 1, 10),
    coalesce(new.raw_user_meta_data->>'display_name', 'Usuario'),
    new.raw_user_meta_data->>'terms_version',
    nullif(new.raw_user_meta_data->>'terms_accepted_at', '')::timestamptz
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.is_staff()
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
      and p.role in ('moderator', 'admin')
      and not p.is_suspended
  );
$$;

create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
    from public.profiles p
    where p.id = auth.uid() and not p.is_suspended
  );
$$;

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
  end if;
  return new;
end;
$$;

create trigger profiles_protect_security_fields
before update on public.profiles
for each row execute function public.protect_profile_security_fields();

create or replace function public.refresh_opportunity_vote_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_id uuid;
begin
  target_id := coalesce(new.opportunity_id, old.opportunity_id);
  update public.opportunities
  set upvote_count = (
    select count(*)::integer
    from public.opportunity_votes v
    where v.opportunity_id = target_id
  )
  where id = target_id;
  return coalesce(new, old);
end;
$$;

create trigger opportunity_votes_refresh_count
after insert or delete on public.opportunity_votes
for each row execute function public.refresh_opportunity_vote_count();

create or replace function public.refresh_opportunity_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_id uuid;
begin
  target_id := coalesce(new.opportunity_id, old.opportunity_id);
  update public.opportunities
  set comment_count = (
    select count(*)::integer
    from public.comments c
    where c.opportunity_id = target_id and not c.is_removed
  )
  where id = target_id;
  return coalesce(new, old);
end;
$$;

create trigger comments_refresh_count
after insert or delete or update of is_removed on public.comments
for each row execute function public.refresh_opportunity_comment_count();

-- Límites defensivos básicos contra spam/abuso. Se aplican en base de datos,
-- no dependen de que el cliente Flutter se comporte correctamente.
create or replace function public.limit_opportunity_submissions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.author_id is not null and not public.is_staff() then
    if (
      select count(*)
      from public.opportunities o
      where o.author_id = new.author_id
        and o.created_at > now() - interval '1 hour'
    ) >= 5 then
      raise exception 'Too many opportunity submissions. Try again later.';
    end if;
  end if;
  return new;
end;
$$;

create trigger opportunities_rate_limit
before insert on public.opportunities
for each row execute function public.limit_opportunity_submissions();

create or replace function public.limit_comment_submissions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() and (
    select count(*)
    from public.comments c
    where c.author_id = new.author_id
      and c.created_at > now() - interval '10 minutes'
  ) >= 20 then
    raise exception 'Too many comments. Try again later.';
  end if;
  return new;
end;
$$;

create trigger comments_rate_limit
before insert on public.comments
for each row execute function public.limit_comment_submissions();

create or replace function public.validate_report_target()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.target_type = 'opportunity' and not exists(select 1 from public.opportunities where id = new.target_id) then
    raise exception 'Invalid report target';
  elsif new.target_type = 'comment' and not exists(select 1 from public.comments where id = new.target_id) then
    raise exception 'Invalid report target';
  elsif new.target_type = 'user' and not exists(select 1 from public.profiles where id = new.target_id) then
    raise exception 'Invalid report target';
  end if;
  return new;
end;
$$;

create trigger reports_validate_target
before insert on public.reports
for each row execute function public.validate_report_target();

create or replace function public.limit_report_submissions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() and (
    select count(*)
    from public.reports r
    where r.reporter_id = new.reporter_id
      and r.created_at > now() - interval '1 hour'
  ) >= 20 then
    raise exception 'Too many reports. Try again later.';
  end if;
  return new;
end;
$$;

create trigger reports_rate_limit
before insert on public.reports
for each row execute function public.limit_report_submissions();

alter table public.profiles enable row level security;
alter table public.opportunities enable row level security;
alter table public.comments enable row level security;
alter table public.opportunity_votes enable row level security;
alter table public.saved_opportunities enable row level security;
alter table public.comment_votes enable row level security;
alter table public.blocked_users enable row level security;
alter table public.reports enable row level security;

create policy profiles_public_read
on public.profiles for select
using (not is_suspended or id = auth.uid() or public.is_staff());

create policy profiles_self_update
on public.profiles for update to authenticated
using (id = auth.uid() and not is_suspended)
with check (id = auth.uid());

create policy profiles_staff_update
on public.profiles for update to authenticated
using (public.is_staff())
with check (public.is_staff());

create policy opportunities_public_read
on public.opportunities for select
using (
  status in ('active', 'expired')
  or author_id = auth.uid()
  or public.is_staff()
);

create policy opportunities_user_insert
on public.opportunities for insert to authenticated
with check (
  public.is_active_user()
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
);

create policy opportunities_staff_all
on public.opportunities for all to authenticated
using (public.is_staff())
with check (public.is_staff());

create policy comments_read
on public.comments for select
using (not is_removed or author_id = auth.uid() or public.is_staff());

create policy comments_insert
on public.comments for insert to authenticated
with check (
  public.is_active_user()
  and author_id = auth.uid()
  and not is_removed
  and exists(
    select 1 from public.opportunities o
    where o.id = opportunity_id and o.status in ('active', 'expired')
  )
);

create policy comments_self_delete
on public.comments for delete to authenticated
using (author_id = auth.uid() or public.is_staff());

create policy comments_staff_update
on public.comments for update to authenticated
using (public.is_staff())
with check (public.is_staff());

create policy votes_read_own
on public.opportunity_votes for select to authenticated
using (user_id = auth.uid());

create policy votes_own
on public.opportunity_votes for all to authenticated
using (user_id = auth.uid() and public.is_active_user())
with check (user_id = auth.uid() and public.is_active_user());

create policy saved_own
on public.saved_opportunities for all to authenticated
using (user_id = auth.uid() and public.is_active_user())
with check (user_id = auth.uid() and public.is_active_user());

create policy comment_votes_own
on public.comment_votes for all to authenticated
using (user_id = auth.uid() and public.is_active_user())
with check (user_id = auth.uid() and public.is_active_user());

create policy blocks_own
on public.blocked_users for all to authenticated
using (blocker_id = auth.uid() and public.is_active_user())
with check (blocker_id = auth.uid() and public.is_active_user());

create policy reports_insert
on public.reports for insert to authenticated
with check (reporter_id = auth.uid() and public.is_active_user());

create policy reports_own_or_staff
on public.reports for select to authenticated
using (reporter_id = auth.uid() or public.is_staff());

create policy reports_staff_update
on public.reports for update to authenticated
using (public.is_staff())
with check (public.is_staff());

create or replace view public.opportunities_public
with (security_invoker = true)
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
  coalesce(p.display_name, p.username, 'GratisCash') as author_name
from public.opportunities o
left join public.profiles p on p.id = o.author_id
where o.status in ('active', 'expired');

create or replace view public.comments_public
with (security_invoker = true)
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
  and not exists(
    select 1
    from public.blocked_users b
    where b.blocker_id = auth.uid() and b.blocked_id = c.author_id
  );

create or replace view public.opportunities_admin
with (security_invoker = true)
as
select
  o.*,
  coalesce(p.display_name, p.username, 'Usuario') as author_name
from public.opportunities o
left join public.profiles p on p.id = o.author_id;

create or replace function public.toggle_opportunity_vote(p_opportunity_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  u uuid := auth.uid();
begin
  if u is null or not public.is_active_user() then
    raise exception 'Authentication required';
  end if;

  if not exists(
    select 1 from public.opportunities o
    where o.id = p_opportunity_id and o.status in ('active', 'expired')
  ) then
    raise exception 'Opportunity not available';
  end if;

  if exists(
    select 1 from public.opportunity_votes
    where opportunity_id = p_opportunity_id and user_id = u
  ) then
    delete from public.opportunity_votes
    where opportunity_id = p_opportunity_id and user_id = u;
  else
    insert into public.opportunity_votes(opportunity_id, user_id)
    values(p_opportunity_id, u);
  end if;
end;
$$;

create or replace function public.toggle_saved_opportunity(p_opportunity_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  u uuid := auth.uid();
begin
  if u is null or not public.is_active_user() then
    raise exception 'Authentication required';
  end if;

  if not exists(
    select 1 from public.opportunities o
    where o.id = p_opportunity_id and o.status in ('active', 'expired')
  ) then
    raise exception 'Opportunity not available';
  end if;

  if exists(
    select 1 from public.saved_opportunities
    where opportunity_id = p_opportunity_id and user_id = u
  ) then
    delete from public.saved_opportunities
    where opportunity_id = p_opportunity_id and user_id = u;
  else
    insert into public.saved_opportunities(opportunity_id, user_id)
    values(p_opportunity_id, u);
  end if;
end;
$$;

create or replace function public.moderate_opportunity(p_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'Forbidden';
  end if;

  if p_status not in ('active', 'expired', 'rejected') then
    raise exception 'Invalid status';
  end if;

  update public.opportunities
  set
    status = p_status::public.opportunity_status,
    moderator_id = auth.uid(),
    moderated_at = now(),
    is_verified = (p_status = 'active')
  where id = p_id;
end;
$$;

revoke all on function public.toggle_opportunity_vote(uuid) from public, anon, authenticated;
revoke all on function public.toggle_saved_opportunity(uuid) from public, anon, authenticated;
revoke all on function public.moderate_opportunity(uuid, text) from public, anon, authenticated;

grant execute on function public.toggle_opportunity_vote(uuid) to authenticated;
grant execute on function public.toggle_saved_opportunity(uuid) to authenticated;
grant execute on function public.moderate_opportunity(uuid, text) to authenticated;

-- Seed inicial: doce oportunidades activas/reales + dos históricas reales, revisadas el 2026-10-02.
-- Los textos son resúmenes propios. Las imágenes son ilustrativas de Unsplash y no se
-- presentan como fotografías oficiales de las marcas. Revalidar cada campaña antes de producción.
insert into public.opportunities(
  id, title, description, source_name, source_url, reward_text, category,
  status, created_at, expires_at, estimated_minutes, image_url, photo_credit,
  photo_source_url, requirements, steps, is_verified, is_featured
)
values
('11111111-1111-4111-8111-111111111111',
  'Encuestas con recompensas en Ipsos iSay',
  'Ipsos iSay permite completar encuestas, acumular puntos y canjearlos por recompensas disponibles para miembros en España. La disponibilidad de estudios depende del perfil de cada persona.',
  'Ipsos iSay',
  'https://www.ipsosisay.com/es-es',
  'Puntos y premios',
  'money',
  'active',
  '2026-10-02T08:00:00Z',
  null,
  null,
  'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1200&q=82',
  'Foto ilustrativa · Unsplash',
  'https://unsplash.com/',
  null,
  '["Regístrate gratis en Ipsos iSay.", "Completa tu perfil para recibir estudios adecuados.", "Participa en las encuestas disponibles.", "Canjea tus puntos por las recompensas disponibles en tu cuenta."]',
  true,
  true),
('22222222-2222-4222-8222-222222222222',
  'Prueba el altavoz Krom Groovy',
  'trnd tiene abierta una campaña para probar el altavoz Bluetooth Krom Groovy y compartir la experiencia siguiendo las condiciones del proyecto.',
  'trnd · Krom',
  'https://www.trnd.com/es/proyectos/krom-groovy/info-producto',
  'Prueba producto',
  'freeProduct',
  'active',
  '2026-09-30T09:00:00Z',
  '2026-11-03T22:59:59Z',
  null,
  'https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?auto=format&fit=crop&w=1200&q=82',
  'Foto ilustrativa · Unsplash',
  'https://unsplash.com/',
  'La selección y las acciones exigidas dependen de las condiciones oficiales del proyecto de trnd.',
  '["Abre la página oficial de trnd.", "Inicia sesión o crea tu cuenta.", "Envía tu candidatura.", "Si eres seleccionado, sigue las instrucciones del proyecto."]',
  true,
  true),
('33333333-3333-4333-8333-333333333333',
  'Prueba Fairy Ultra Original + Fairy Spray',
  'Campaña activa de trnd para probar el dúo Fairy. La página oficial indica 10.000 participantes/influencers para el proyecto.',
  'trnd · Fairy',
  'https://www.trnd.com/es/proyectos/fairy-original-spray/info-producto',
  'Prueba producto',
  'freeProduct',
  'active',
  '2026-09-18T09:00:00Z',
  '2026-11-26T22:59:59Z',
  null,
  'https://images.unsplash.com/photo-1556911220-bff31c812dba?auto=format&fit=crop&w=1200&q=82',
  'Foto ilustrativa · Unsplash',
  'https://unsplash.com/',
  null,
  '["Accede al proyecto oficial.", "Envía tu candidatura.", "Espera la selección de participantes.", "Completa las acciones indicadas si resultas seleccionado."]',
  true,
  true),
('44444444-4444-4444-8444-444444444444',
  'Prueba el Aceite Glowtox de Pantene',
  'Campaña activa de trnd para probar el Aceite Glowtox de Pantene. Si resultas seleccionado recibirás el producto y deberás cumplir las acciones de contenido indicadas por la campaña.',
  'trnd · Pantene',
  'https://www.trnd.com/es/proyectos/aceite-glowtox-pantene/info-proyecto',
  'Prueba producto',
  'freeProduct',
  'active',
  '2026-09-14T09:00:00Z',
  '2026-11-30T22:59:59Z',
  null,
  'https://images.unsplash.com/photo-1556229010-6c3f2c9ca5f8?auto=format&fit=crop&w=1200&q=82',
  'Foto ilustrativa · Unsplash',
  'https://unsplash.com/',
  'La campaña solicita crear contenidos en redes sociales si eres una de las personas seleccionadas. Revisa la información oficial antes de participar.',
  '["Abre la campaña oficial.", "Envía tu candidatura.", "Consulta las condiciones completas.", "Participa solo si resultas seleccionado."]',
  true,
  false),
('55555555-5555-4555-8555-555555555555',
  '500 familias para probar Puleva MAX',
  'trnd busca 500 familias con niños de 3 años para probar Puleva MAX y compartir su experiencia en el inicio del cole.',
  'trnd · Puleva',
  'https://www.trnd.com/es/proyectos/lactalis-puleva/producto',
  'Prueba producto',
  'freeProduct',
  'active',
  '2026-09-10T09:00:00Z',
  '2026-10-30T22:59:59Z',
  null,
  'https://images.unsplash.com/photo-1519689680058-324335c77eba?auto=format&fit=crop&w=1200&q=82',
  'Foto ilustrativa · Unsplash',
  'https://unsplash.com/',
  'Campaña orientada a familias con niños de 3 años. Revisa los criterios definitivos en la página oficial.',
  '["Consulta la campaña oficial.", "Comprueba si encajas en el perfil solicitado.", "Envía tu candidatura.", "Sigue las indicaciones de trnd si eres seleccionado."]',
  true,
  false),
('66666666-6666-4666-8666-666666666666',
  'Prueba Ausonia Discreet',
  'Proyecto de trnd para conocer una solución de protección frente a pérdidas de orina. La campaña aparece entre los proyectos activos de trnd España.',
  'trnd · Ausonia',
  'https://www.trnd.com/es/proyectos',
  'Prueba producto',
  'freeProduct',
  'active',
  '2026-08-14T09:00:00Z',
  '2026-10-22T22:59:59Z',
  null,
  'https://images.unsplash.com/photo-1556228720-195a672e8a03?auto=format&fit=crop&w=1200&q=82',
  'Foto ilustrativa · Unsplash',
  'https://unsplash.com/',
  'Consulta en trnd el perfil de selección y las condiciones completas antes de enviar tu candidatura.',
  '["Abre la lista oficial de proyectos de trnd.", "Localiza Ausonia Discreet.", "Comprueba el perfil solicitado y envía tu candidatura.", "Sigue las instrucciones si resultas seleccionada."]',
  true,
  true),
('77777777-7777-4777-8777-777777777777',
  'Proyecto Nestlé NAN SUPREMEPRO 2 y 3',
  'Proyecto de trnd sobre las fórmulas NAN SUPREMEPRO 2 y 3 de Nestlé. La campaña figura activa en el listado oficial de proyectos.',
  'trnd · Nestlé',
  'https://www.trnd.com/es/proyectos',
  'Proyecto activo',
  'freeProduct',
  'active',
  '2026-06-23T09:00:00Z',
  '2026-10-14T22:59:59Z',
  null,
  'https://images.unsplash.com/photo-1519689680058-324335c77eba?auto=format&fit=crop&w=1200&q=82',
  'Foto ilustrativa · Unsplash',
  'https://unsplash.com/',
  'Revisa en la ficha de trnd los criterios de participación y toda la información nutricional aplicable.',
  '["Consulta el listado oficial de proyectos.", "Abre la campaña NAN SUPREMEPRO.", "Lee los criterios y condiciones.", "Participa únicamente si cumples el perfil indicado."]',
  true,
  false),
('88888888-8888-4888-8888-888888888888',
  'Prueba Gratis Glade con reembolso de Gelt',
  'Promoción nacional de Gelt para productos Glade incluidos. Las bases contemplan un reembolso de hasta 6 € por producto promocionado, sujeto a unidades disponibles y validación del ticket.',
  'Gelt · Glade',
  'https://gelt.com/es/bases-legales/bases-legales-de-prueba-gratis-glade/',
  'Hasta 6 €',
  'cashback',
  'active',
  '2026-08-01T09:00:00Z',
  '2027-01-31T22:59:59Z',
  null,
  'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=format&fit=crop&w=1200&q=82',
  'Foto ilustrativa · Unsplash',
  'https://unsplash.com/',
  'Es necesario comprar un producto incluido, conservar el ticket y cumplir las bases. La promoción puede finalizar antes si se agotan las unidades disponibles.',
  '["Comprueba qué productos participan.", "Compra un producto válido durante el periodo promocional.", "Sube una foto legible del ticket según las instrucciones de Gelt.", "Espera la validación y el reembolso si la participación es correcta."]',
  true,
  true),
('99999999-9999-4999-8999-999999999999',
  '20 € de bienvenida para nuevos clientes de Revolut',
  'Promoción oficial de Revolut para nuevos clientes residentes en España. La campaña ofrece una recompensa de 20 € después de abrir la cuenta mediante el enlace promocional y cumplir los pasos exigidos.',
  'Revolut',
  'https://www.revolut.com/es-ES/primavera-website-banner/',
  '20 €',
  'bonus',
  'active',
  '2026-10-02T09:00:00Z',
  '2026-12-31T22:59:59Z',
  null,
  'https://images.unsplash.com/photo-1563013544-824ae1b704d7?auto=format&fit=crop&w=1200&q=82',
  'Foto ilustrativa · Unsplash',
  'https://unsplash.com/',
  'Solo para nuevos clientes mayores de 18 años. Debes registrarte desde la página promocional y cumplir el gasto mínimo indicado en las condiciones oficiales.',
  '["Abre la página oficial de la promoción.", "Introduce tu teléfono y abre la cuenta desde el enlace recibido.", "Completa el gasto mínimo exigido con una compra válida.", "Revolut abonará la recompensa si cumples las condiciones."]',
  true,
  true),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Encuestas y recompensas en Toluna',
  'Toluna ofrece encuestas remuneradas con puntos que pueden canjearse por recompensas como vales y opciones de pago disponibles en su catálogo español.',
  'Toluna',
  'https://www.toluna.com/es/rewards-landing-page',
  'Puntos y premios',
  'money',
  'active',
  '2026-10-02T10:00:00Z',
  null,
  null,
  'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=82',
  'Foto ilustrativa · Unsplash',
  'https://unsplash.com/',
  null,
  '["Crea una cuenta gratuita en Toluna.", "Completa tu perfil.", "Participa en las encuestas disponibles.", "Canjea los puntos por las recompensas disponibles."]',
  true,
  false),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'Encuestas remuneradas de MOBROG',
  'MOBROG publica encuestas online para residentes en España. Su web indica recompensas de entre 0,50 € y 3 € por encuestas breves, con opciones de cobro que dependen del país.',
  'MOBROG',
  'https://www.mobrog.com/es/c%C3%B3mo-funciona/',
  '0,50–3 €',
  'money',
  'active',
  '2026-10-02T11:00:00Z',
  null,
  null,
  'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1200&q=82',
  'Foto ilustrativa · Unsplash',
  'https://unsplash.com/',
  null,
  '["Regístrate y activa tu perfil.", "Completa tu información de perfil.", "Participa en las encuestas para las que encajes.", "Solicita el pago cuando alcances el mínimo aplicable."]',
  true,
  false),
('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'Misiones remuneradas en tiendas con Roamler',
  'Roamler permite realizar tareas desde el móvil, como comprobar productos y precios, recoger fotos o datos en tiendas y otras misiones disponibles según tu zona.',
  'Roamler',
  'https://www.roamler.com/roamlers/retail/es/',
  'Pago por tarea',
  'mission',
  'active',
  '2026-10-02T12:00:00Z',
  null,
  null,
  'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?auto=format&fit=crop&w=1200&q=82',
  'Foto ilustrativa · Unsplash',
  'https://unsplash.com/',
  'La disponibilidad, ubicación, requisitos y remuneración dependen de las tareas activas que aparezcan en la app de Roamler.',
  '["Descarga la app de Roamler y regístrate.", "Consulta las tareas disponibles cerca de ti.", "Reserva y completa una tarea siguiendo las instrucciones.", "Envía el resultado y cobra cuando la tarea sea aprobada."]',
  true,
  false),
('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'Magno Be Wild · proyecto finalizado',
  'Proyecto de trnd que figuró activo en septiembre de 2026. GratisCash conserva la ficha para mostrar el histórico cuando una campaña ya ha terminado.',
  'trnd · Magno',
  'https://www.trnd.com/es/proyectos',
  'Proyecto finalizado',
  'freeProduct',
  'expired',
  '2026-09-02T09:00:00Z',
  '2026-09-30T22:59:59Z',
  null,
  'https://images.unsplash.com/photo-1556228720-195a672e8a03?auto=format&fit=crop&w=1200&q=82',
  'Foto ilustrativa · Unsplash',
  'https://unsplash.com/',
  null,
  '[]',
  true,
  false),
('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'Fairy Ultra Original · proyecto finalizado',
  'Proyecto anterior de trnd ya finalizado. GratisCash lo mantiene para que el histórico no desaparezca cuando una oportunidad termina.',
  'trnd · Fairy',
  'https://www.trnd.com/es/proyectos',
  'Proyecto finalizado',
  'freeProduct',
  'expired',
  '2025-11-10T09:00:00Z',
  '2026-01-27T22:59:59Z',
  null,
  'https://images.unsplash.com/photo-1556911220-bff31c812dba?auto=format&fit=crop&w=1200&q=82',
  'Foto ilustrativa · Unsplash',
  'https://unsplash.com/',
  null,
  '[]',
  true,
  false)
on conflict(id) do nothing;
