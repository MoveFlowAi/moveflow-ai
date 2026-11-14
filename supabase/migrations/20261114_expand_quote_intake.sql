-- MoveFlow AI quote intake expansion. Safe to run on existing populated database.
begin;
alter table public.leads
  add column if not exists customer_phone text,
  add column if not exists move_type text,
  add column if not exists bedrooms integer,
  add column if not exists access_details text,
  add column if not exists additional_details text,
  add column if not exists preferred_contact_method text,
  add column if not exists consent_to_contact boolean,
  add column if not exists consent_recorded_at timestamptz;
commit;
-- Existing rows remain unchanged; new columns are nullable for backwards compatibility.
-- After deploying the updated Edge Function, the server validates allowed values and lengths.
