-- Server-side feature gates for MoveFlow AI.
-- Run ONLY after 20261114_operations.sql and 20261114_plan_entitlements.sql.
-- Test in staging first. Existing operations policies are replaced.
-- No active subscription record = no paid feature access.
BEGIN;
CREATE OR REPLACE FUNCTION public.moveflow_has_feature(p_company_id uuid, p_feature text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
 SELECT EXISTS (
   SELECT 1 FROM public.company_members m
   JOIN public.company_plan_assignments a ON a.company_id=m.company_id
   WHERE m.user_id=(SELECT auth.uid()) AND m.company_id=p_company_id
     AND a.billing_status='active'
     AND (
       (p_feature='estimates' AND a.plan IN ('growth','premium'))
       OR (p_feature='scheduling' AND a.plan='premium')
     )
 );
$$;
REVOKE ALL ON FUNCTION public.moveflow_has_feature(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.moveflow_has_feature(uuid,text) TO authenticated;
-- Policies are OR-combined in Postgres; old permissive member policies must be removed.
DROP POLICY IF EXISTS "Members read estimates" ON public.move_estimates;
DROP POLICY IF EXISTS "Members insert estimates" ON public.move_estimates;
DROP POLICY IF EXISTS "Members update estimates" ON public.move_estimates;
DROP POLICY IF EXISTS "Members read jobs" ON public.move_jobs;
DROP POLICY IF EXISTS "Members insert jobs" ON public.move_jobs;
DROP POLICY IF EXISTS "Members update jobs" ON public.move_jobs;
CREATE POLICY "Paid members read estimates" ON public.move_estimates FOR SELECT TO authenticated
USING (public.moveflow_has_feature(company_id,'estimates'));
CREATE POLICY "Paid members insert estimates" ON public.move_estimates FOR INSERT TO authenticated
WITH CHECK (public.moveflow_has_feature(company_id,'estimates'));
CREATE POLICY "Paid members update estimates" ON public.move_estimates FOR UPDATE TO authenticated
USING (public.moveflow_has_feature(company_id,'estimates'))
WITH CHECK (public.moveflow_has_feature(company_id,'estimates'));
CREATE POLICY "Paid members read jobs" ON public.move_jobs FOR SELECT TO authenticated
USING (public.moveflow_has_feature(company_id,'scheduling'));
CREATE POLICY "Paid members insert jobs" ON public.move_jobs FOR INSERT TO authenticated
WITH CHECK (public.moveflow_has_feature(company_id,'scheduling'));
CREATE POLICY "Paid members update jobs" ON public.move_jobs FOR UPDATE TO authenticated
USING (public.moveflow_has_feature(company_id,'scheduling'))
WITH CHECK (public.moveflow_has_feature(company_id,'scheduling'));
COMMIT;
-- Security test: starter cannot read/write estimates or jobs; growth only estimates;
-- premium both; past_due/canceled/trial none. Cross-tenant access always denied.
-- Service role bypasses RLS: do not expose it in client code.
