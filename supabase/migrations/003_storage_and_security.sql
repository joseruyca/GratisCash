-- GratisCash · Storage y endurecimiento adicional
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
