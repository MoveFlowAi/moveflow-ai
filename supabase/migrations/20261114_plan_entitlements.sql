-- MoveFlow AI plan entitlement groundwork; NO payment processor connected.
-- Only trusted administrators/service-role processes should change company_plan_assignments.
BEGIN;
CREATE TABLE IF NOT EXISTS public.company_plan_assignments (
 company_id uuid PRIMARY KEY REFERENCES public.companies(id) ON DELETE CASCADE,
 plan text NOT NULL DEFAULT 'starter' CHECK (plan IN ('starter','growth','premium')),
 billing_status text NOT NULL DEFAULT 'trial' CHECK (billing_status IN ('trial','active','past_due','canceled')),
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.company_plan_assignments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.company_plan_assignments FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.company_plan_assignments TO authenticated;
DROP POLICY IF EXISTS "Members read own plan" ON public.company_plan_assignments;
CREATE POLICY "Members read own plan" ON public.company_plan_assignments FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.company_members m WHERE m.company_id=company_plan_assignments.company_id AND m.user_id=(SELECT auth.uid())));
-- No INSERT/UPDATE/DELETE grant or policy for authenticated users.
-- Populate rows only after manual verification of the company and payment status.
-- Subscription feature gates must also be checked by trusted backend functions and RLS.
COMMIT;
