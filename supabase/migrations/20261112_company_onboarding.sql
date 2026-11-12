-- MoveFlow AI phase 2: secure company onboarding and lead-status updates
-- Run ONCE in Supabase SQL Editor after reviewing.
-- New companies start inactive until the owner verifies them.

create or replace function public.register_moving_company(p_name text,p_slug text)
returns uuid language plpgsql security definer
set search_path = '' as $$
declare v_id uuid; v_uid uuid := (select auth.uid());
begin
 if v_uid is null then raise exception 'Sign in required'; end if;
 if length(trim(p_name)) < 2 or length(trim(p_name)) > 120 then raise exception 'Invalid company name'; end if;
 if p_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' or length(p_slug)>60 then raise exception 'Invalid company slug'; end if;
 if exists(select 1 from public.company_members where user_id=v_uid) then raise exception 'You already have a company account'; end if;
 insert into public.companies(name,slug,active) values(trim(p_name),p_slug,false) returning id into v_id;
 insert into public.company_members(company_id,user_id) values(v_id,v_uid);
 return v_id;
end $$;
revoke all on function public.register_moving_company(text,text) from public;
grant execute on function public.register_moving_company(text,text) to authenticated;

-- Company users should not update the entire lead row.
drop policy if exists "Update assigned leads" on public.leads;
revoke update on public.leads from anon,authenticated;

create or replace function public.set_lead_status(p_lead uuid,p_status text)
returns void language plpgsql security definer
set search_path = '' as $$
begin
 if (select auth.uid()) is null then raise exception 'Sign in required'; end if;
 if p_status not in ('new','contacted','quoted','booked','closed') then raise exception 'Invalid status'; end if;
 update public.leads l set status=p_status
 where l.id=p_lead and exists(
   select 1 from public.company_members m
   where m.company_id=l.company_id and m.user_id=(select auth.uid())
 );
 if not found then raise exception 'Lead not found or access denied'; end if;
end $$;
revoke all on function public.set_lead_status(uuid,text) from public;
grant execute on function public.set_lead_status(uuid,text) to authenticated;

-- No public insert policies: lead creation must happen through trusted backend.
-- Do not expose a service-role or secret key in the browser.
