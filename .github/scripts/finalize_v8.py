from pathlib import Path
import sys
root = Path(sys.argv[1])

# Brand migration, preserving Spanish words such as oportunidad/oportunidades.
for p in root.rglob('*'):
    if not p.is_file():
        continue
    try:
        s = p.read_text(encoding='utf-8')
    except Exception:
        continue
    n = s.replace('OPORTU', 'GRATISCASH').replace('Oportu', 'GratisCash').replace('oportu', 'gratiscash')
    n = (n.replace('GratisCashnidades', 'Oportunidades')
          .replace('GratisCashnidad', 'Oportunidad')
          .replace('gratiscashnidades', 'oportunidades')
          .replace('gratiscashnidad', 'oportunidad')
          .replace('GRATISCASHNIDADES', 'OPORTUNIDADES')
          .replace('GRATISCASHNIDAD', 'OPORTUNIDAD'))
    if n != s:
        p.write_text(n, encoding='utf-8')

old = root / 'supabase/migrations/001_oportu.sql'
new = root / 'supabase/migrations/001_gratiscash.sql'
if old.exists():
    old.rename(new)

# Release version.
p = root / 'pubspec.yaml'
s = p.read_text(encoding='utf-8').replace('version: 1.5.0+7', 'version: 1.6.0+8')
p.write_text(s, encoding='utf-8')

# Exact public client configuration. These are browser-safe public values, never service_role.
(root / 'lib/core/config.dart').write_text('''class AppConfig {
  static const appEnvironment = String.fromEnvironment('APP_ENV', defaultValue: 'staging');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://qmuyrobiqowcjgbpyliv.supabase.co');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_QzSCaKTlqSbzaBNHCWqs9Q_2ugIP0AW',
  );
  static const legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const legalOwner = String.fromEnvironment(
    'LEGAL_OWNER',
    defaultValue: 'PENDIENTE DE COMPLETAR',
  );
  static const legalEmail = String.fromEnvironment(
    'LEGAL_EMAIL',
    defaultValue: 'PENDIENTE DE COMPLETAR',
  );
  static const legalAddress = String.fromEnvironment(
    'LEGAL_ADDRESS',
    defaultValue: 'PENDIENTE DE COMPLETAR',
  );
  static const websiteUrl = String.fromEnvironment(
    'WEBSITE_URL',
    defaultValue: 'https://gratiscashv1.vercel.app',
  );
  static const authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'https://gratiscashv1.vercel.app/auth',
  );

  static const termsVersion = '2026-10-06';
  static const minimumAccountAge = 18;

  static String get supabaseClientKey => supabasePublishableKey.isNotEmpty
      ? supabasePublishableKey
      : legacyAnonKey;

  static bool get isProduction => appEnvironment.toLowerCase() == 'production';

  static bool get backendConfigured =>
      supabaseUrl.startsWith('https://') && supabaseClientKey.isNotEmpty;

  static bool get legalConfigured =>
      !_isPlaceholder(legalOwner) &&
      !_isPlaceholder(legalEmail) &&
      !_isPlaceholder(legalAddress);

  static bool _isPlaceholder(String value) {
    final normalized = value.trim().toUpperCase();
    return normalized.isEmpty || normalized.contains('PENDIENTE');
  }
}
''', encoding='utf-8')

# Staging builds can be tested; true production remains gated until legal identity is complete.
p = root / 'lib/main.dart'
s = p.read_text(encoding='utf-8').replace(
    'if (kReleaseMode && !AppConfig.legalConfigured)',
    'if (kReleaseMode && AppConfig.isProduction && !AppConfig.legalConfigured)',
)
p.write_text(s, encoding='utf-8')

# Correct reverse-DNS org for generated mobile/web shells.
p = root / 'tool/bootstrap.ps1'
s = p.read_text(encoding='utf-8').replace('--org app.gratiscash', '--org com.gratiscash')
p.write_text(s, encoding='utf-8')

(root / '.env.example').write_text('''# GratisCash · configuración pública del cliente (nunca service_role)
APP_ENV=staging
SUPABASE_URL=https://qmuyrobiqowcjgbpyliv.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
WEBSITE_URL=https://gratiscashv1.vercel.app
AUTH_REDIRECT_URL=https://gratiscashv1.vercel.app/auth

# Obligatorias antes de APP_ENV=production
LEGAL_OWNER=PENDIENTE DE COMPLETAR
LEGAL_EMAIL=PENDIENTE DE COMPLETAR
LEGAL_ADDRESS=PENDIENTE_DE_COMPLETAR
'''.replace('PENDIENTE_DE_COMPLETAR','PENDIENTE DE COMPLETAR'), encoding='utf-8')

(root / 'vercel.json').write_text('''{
  "installCommand": "bash vercel_build.sh install",
  "buildCommand": "bash vercel_build.sh build",
  "outputDirectory": "build/web",
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
''', encoding='utf-8')

(root / 'vercel_build.sh').write_text('''#!/usr/bin/env bash
set -euo pipefail
FLUTTER_HOME="$HOME/flutter"
export PATH="$FLUTTER_HOME/bin:$PATH"
if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi
flutter config --enable-web
flutter --version
flutter create --platforms=web --org com.gratiscash --project-name gratiscash .
if [ "${1:-}" = "install" ]; then
  flutter pub get
  exit 0
fi
if [ "${1:-}" = "build" ]; then
  flutter build web --release \
    --dart-define=APP_ENV="${APP_ENV:-staging}" \
    --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://qmuyrobiqowcjgbpyliv.supabase.co}" \
    --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-sb_publishable_QzSCaKTlqSbzaBNHCWqs9Q_2ugIP0AW}" \
    --dart-define=WEBSITE_URL="${WEBSITE_URL:-https://gratiscashv1.vercel.app}" \
    --dart-define=AUTH_REDIRECT_URL="${AUTH_REDIRECT_URL:-https://gratiscashv1.vercel.app/auth}" \
    --dart-define=LEGAL_OWNER="${LEGAL_OWNER:-PENDIENTE DE COMPLETAR}" \
    --dart-define=LEGAL_EMAIL="${LEGAL_EMAIL:-PENDIENTE DE COMPLETAR}" \
    --dart-define=LEGAL_ADDRESS="${LEGAL_ADDRESS:-PENDIENTE DE COMPLETAR}"
  exit 0
fi
echo "Usage: bash vercel_build.sh install|build" >&2
exit 2
''', encoding='utf-8')

(root / 'supabase/migrations/003_storage_and_security.sql').write_text(r'''-- GratisCash · Storage y endurecimiento adicional
-- Ejecutar después de 001_gratiscash.sql y 002_production_hardening.sql.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('opportunity-images', 'opportunity-images', true, 8388608, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own on storage.objects for insert to authenticated
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid()::text));

drop policy if exists avatars_select_own on storage.objects;
create policy avatars_select_own on storage.objects for select to authenticated
using (bucket_id = 'avatars' and owner_id = (select auth.uid()::text));

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own on storage.objects for update to authenticated
using (bucket_id = 'avatars' and owner_id = (select auth.uid()::text))
with check (bucket_id = 'avatars' and owner_id = (select auth.uid()::text));

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own on storage.objects for delete to authenticated
using (bucket_id = 'avatars' and owner_id = (select auth.uid()::text));

drop policy if exists opportunity_images_insert_own on storage.objects;
create policy opportunity_images_insert_own on storage.objects for insert to authenticated
with check (
  bucket_id = 'opportunity-images'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and public.is_active_user()
);

drop policy if exists opportunity_images_select_own on storage.objects;
create policy opportunity_images_select_own on storage.objects for select to authenticated
using (bucket_id = 'opportunity-images' and owner_id = (select auth.uid()::text));

drop policy if exists opportunity_images_update_own on storage.objects;
create policy opportunity_images_update_own on storage.objects for update to authenticated
using (bucket_id = 'opportunity-images' and owner_id = (select auth.uid()::text))
with check (bucket_id = 'opportunity-images' and owner_id = (select auth.uid()::text));

drop policy if exists opportunity_images_delete_own on storage.objects;
create policy opportunity_images_delete_own on storage.objects for delete to authenticated
using (bucket_id = 'opportunity-images' and owner_id = (select auth.uid()::text));

revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.touch_updated_at() from public, anon, authenticated;
revoke execute on function public.protect_profile_security_fields() from public, anon, authenticated;
revoke execute on function public.refresh_opportunity_vote_count() from public, anon, authenticated;
revoke execute on function public.refresh_opportunity_comment_count() from public, anon, authenticated;
revoke execute on function public.prepare_opportunity_for_write() from public, anon, authenticated;

revoke all on function public.is_staff() from public, anon, authenticated;
grant execute on function public.is_staff() to authenticated;
revoke all on function public.is_active_user() from public, anon, authenticated;
grant execute on function public.is_active_user() to authenticated;

grant usage on schema public to anon, authenticated;
grant select on public.profiles_public, public.opportunities_public, public.comments_public to anon, authenticated;
grant select, insert, update, delete on public.profiles, public.opportunities, public.comments, public.opportunity_votes, public.saved_opportunities, public.comment_votes, public.blocked_users, public.reports, public.moderation_appeals to authenticated;
grant select on public.moderation_actions, public.user_moderation_actions to authenticated;
''', encoding='utf-8')

(root / 'CHANGELOG_V8.md').write_text('''# GratisCash V8

- Renombrado integral de la marca a GratisCash.
- Restauradas todas las pantallas del V7 original.
- Versión 1.6.0+8.
- Entornos staging / production; producción real exige datos legales completos.
- Build Flutter web reproducible para Vercel.
- Supabase real preparado con RLS, moderación, duplicados, apelaciones y Storage.
- Buckets seguros para avatares e imágenes de oportunidades.
- SECURITY DEFINER internos revocados como API pública cuando no son endpoints.
- Sin service_role ni claves secretas en el frontend.
''', encoding='utf-8')
