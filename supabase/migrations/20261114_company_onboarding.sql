-- MoveFlow AI: self-service company onboarding
-- Run in Supabase SQL Editor after reviewing existing RLS policies.
-- Existing companies, members, and leads are not modified.
create or replace function public.register_moving_company(p_name text, p_slug text, p_zip text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid()); v_company uuid;
begin
  if v_uid is null then raise exception 'Sign in required'; end if;
  if not exists (select 1 from auth.users where id=v_uid and email_confirmed_at is not null)
    then raise exception 'Confirm your email before registering a company'; end if;
  if length(trim(coalesce(p_name,''))) not between 2 and 120
    then raise exception 'Company name must be 2 to 120 characters'; end if;
  if p_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' or length(p_slug) not between 3 and 60
    then raise exception 'Invalid company slug'; end if;
  if p_zip !~ '^[0-9]{5}$' then raise exception 'Enter a five-digit service ZIP'; end if;
  -- One self-registered company per user for initial rollout.
  if exists(select 1 from public.company_members where user_id=v_uid)
    then raise exception 'You already belong to a company; contact support to create another'; end if;
  insert into public.companies(name,slug,active)
    values(trim(p_name),p_slug,false) returning id into v_company;
  insert into public.company_members(company_id,user_id) values(v_company,v_uid);
  insert into public.service_areas(company_id,zip_code) values(v_company,p_zip);
  return v_company;
end; $$;
revoke all on function public.register_moving_company(text,text,text) from public, anon;
grant execute on function public.register_moving_company(text,text,text) to authenticated;
-- IMPORTANT: Newly registered companies are inactive until manually reviewed.
-- Confirm existing RLS on companies, company_members, leads, and service_areas
-- before enabling registration. A SECURITY DEFINER function must be reviewed
-- against existing policies and any additional triggers/constraints.
