-- Awareness — card-photo sync (opt-in)
-- Run this ONCE in the Supabase project's SQL editor
-- (Dashboard → SQL Editor → New query → paste → Run).
--
-- It creates a PRIVATE storage bucket for the user's card photos and grants the
-- anon role (the publishable key) read/write access. Per-user isolation is by the
-- unguessable sync_key hash used as the object path prefix — the same trust model
-- as the existing `blackout_events` table (the publishable key is public; the
-- sync_key derived from the user's passphrase is the bearer secret).
--
-- Object layout:  {sync_key_hash}/card-<cardId>-<front|back>.png
--                 {sync_key_hash}/manifest.json   (carries the manual card selection)

-- 1. Private bucket (not public — objects require the apikey header, no hot-linking)
insert into storage.buckets (id, name, public)
values ('card-assets', 'card-assets', false)
on conflict (id) do nothing;

-- 2. Anon RLS policies scoped to this bucket
drop policy if exists "card-assets anon read"   on storage.objects;
drop policy if exists "card-assets anon insert" on storage.objects;
drop policy if exists "card-assets anon update" on storage.objects;
drop policy if exists "card-assets anon delete" on storage.objects;

create policy "card-assets anon read"
  on storage.objects for select to anon
  using (bucket_id = 'card-assets');

create policy "card-assets anon insert"
  on storage.objects for insert to anon
  with check (bucket_id = 'card-assets');

create policy "card-assets anon update"
  on storage.objects for update to anon
  using (bucket_id = 'card-assets')
  with check (bucket_id = 'card-assets');

create policy "card-assets anon delete"
  on storage.objects for delete to anon
  using (bucket_id = 'card-assets');
