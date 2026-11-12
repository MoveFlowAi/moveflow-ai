-- MoveFlow AI initial database schema backup
-- Reconstructed from the original setup supplied in this conversation.
-- This is a schema/policy backup, NOT a backup of customer records.
-- Do not run against an existing populated database without reviewing it first.

create extension if not exists pgcrypto;

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  active boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.company_members (
  company_id uuid not null references public.companies(id),
  user_id uuid not null references auth.users(id),
  primary key (company_id, user_id)
);

create table public.service_areas (
  company_id uuid not null references public.companies(id),
  zip_code text not null,
  primary key (company_id, zip_code)
);

create table public.leads (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  customer_name text not null,
  customer_email text not null,
  pickup_zip text not null,
  destination_zip text,
  move_date date,
  status text not null default 'new'
    check (status in ('new','contacted','quoted','booked','closed')),
  created_at timestamptz not null default now()
);

alter table public.companies enable row level security;
alter table public.company_members enable row level security;
alter table public.service_areas enable row level security;
alter table public.leads enable row level security;

create policy "Read own memberships"
on public.company_members
for select to authenticated
using (user_id = (select auth.uid()));

create policy "Read assigned companies"
on public.companies
for select to authenticated
using (
  id in (
    select company_id from public.company_members
    where user_id = (select auth.uid())
  )
);

create policy "Read assigned service areas"
on public.service_areas
for select to authenticated
using (
  company_id in (
    select company_id from public.company_members
    where user_id = (select auth.uid())
  )
);

create policy "Read assigned leads"
on public.leads
for select to authenticated
using (
  company_id in (
    select company_id from public.company_members
    where user_id = (select auth.uid())
  )
);

create policy "Update assigned leads"
on public.leads
for update to authenticated
using (
  company_id in (
    select company_id from public.company_members
    where user_id = (select auth.uid())
  )
)
with check (
  company_id in (
    select company_id from public.company_members
    where user_id = (select auth.uid())
  )
);
