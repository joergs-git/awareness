-- Awareness — security audit 2026-10-16, finding P1 (LOW): per-user isolation for
-- public.blackout_events and the card-assets storage bucket via the x-sync-key request header.
--
-- *** NOT APPLIED YET (as of 2026-10-24). ***
-- Apply only once app versions that send the x-sync-key header are widespread:
-- iOS/watchOS >= 5.2.2 (build 16), macOS >= 5.2.2, Windows >= 5.2.2.
-- Older clients send no header and lose sync the moment this runs (their events queue
-- locally; the desktop queue drops events older than 7 days).
--
-- Trust model: every client sends SHA-256(passphrase) both as the sync_key column value and as
-- the x-sync-key header; a row/object is accepted only when the two match. Without the header
-- nothing is visible, so third parties can no longer read the hashes. The only remaining attack
-- is online guessing of the ~38-bit passphrase through the REST API.
--
-- Acceptance (curl against the live project with the publishable key):
--   anon without header         -> 0 rows / 0 objects
--   anon with a foreign header  -> 0 rows / 0 objects
--   anon with own header        -> only own rows / objects
--   UPDATE on foreign rows      -> 0 rows affected
-- Storage: PostgREST exposes request.headers to policies; confirm the Storage API does too on
-- this project (list/download with and without header) before relying on the bucket policies.

-- 1. blackout_events ---------------------------------------------------------------------
drop policy if exists "allow_select"      on public.blackout_events;
drop policy if exists "allow_insert"      on public.blackout_events;
drop policy if exists "Allow anon update" on public.blackout_events;

create policy "own_sync_key_select" on public.blackout_events for select to anon
  using (sync_key = current_setting('request.headers', true)::json ->> 'x-sync-key');
create policy "own_sync_key_insert" on public.blackout_events for insert to anon
  with check (sync_key = current_setting('request.headers', true)::json ->> 'x-sync-key');
create policy "own_sync_key_update" on public.blackout_events for update to anon
  using      (sync_key = current_setting('request.headers', true)::json ->> 'x-sync-key')
  with check (sync_key = current_setting('request.headers', true)::json ->> 'x-sync-key');

-- No client ever deletes; remove the privilege entirely (TRUNCATE is not covered by RLS).
revoke delete, truncate on public.blackout_events from anon, authenticated;
create index if not exists blackout_events_sync_key_idx on public.blackout_events (sync_key);

-- 2. card-assets bucket ------------------------------------------------------------------
-- Objects live at "{sync_key_hash}/..."; the first path segment must equal the header.
drop policy if exists "card-assets anon read"   on storage.objects;
drop policy if exists "card-assets anon insert" on storage.objects;
drop policy if exists "card-assets anon update" on storage.objects;
drop policy if exists "card-assets anon delete" on storage.objects;

create policy "card-assets own prefix read" on storage.objects for select to anon
  using (bucket_id = 'card-assets'
         and (storage.foldername(name))[1] = current_setting('request.headers', true)::json ->> 'x-sync-key');
create policy "card-assets own prefix insert" on storage.objects for insert to anon
  with check (bucket_id = 'card-assets'
         and (storage.foldername(name))[1] = current_setting('request.headers', true)::json ->> 'x-sync-key');
create policy "card-assets own prefix update" on storage.objects for update to anon
  using      (bucket_id = 'card-assets'
         and (storage.foldername(name))[1] = current_setting('request.headers', true)::json ->> 'x-sync-key')
  with check (bucket_id = 'card-assets'
         and (storage.foldername(name))[1] = current_setting('request.headers', true)::json ->> 'x-sync-key');
-- No client deletes objects (union model) — deliberately no delete policy.
