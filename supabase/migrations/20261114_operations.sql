-- MoveFlow AI operations MVP: company-scoped estimates and scheduling.
-- Apply AFTER reviewing schema and tenant policies in a staging Supabase project.
-- No payments, external messages, or subscriptions are activated by this migration.
BEGIN;
CREATE TABLE IF NOT EXISTS public.move_estimates (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
 lead_id uuid NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
 amount_cents integer NOT NULL CHECK (amount_cents >= 0 AND amount_cents <= 100000000),
 description text NOT NULL DEFAULT '' CHECK (char_length(description)<=2000),
 state text NOT NULL DEFAULT 'draft' CHECK (state IN ('draft','sent','accepted','declined')),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(company_id,lead_id)
);
CREATE TABLE IF NOT EXISTS public.move_jobs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
 lead_id uuid NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
 scheduled_at timestamptz NOT NULL,
 notes text NOT NULL DEFAULT '' CHECK (char_length(notes)<=2000),
 state text NOT NULL DEFAULT 'scheduled' CHECK (state IN ('scheduled','completed','cancelled')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(company_id,lead_id)
);
-- Guard against pairing a lead with another company's ID, including through SQL API calls.
CREATE OR REPLACE FUNCTION public.verify_moveflow_lead_company()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.leads l WHERE l.id=NEW.lead_id AND l.company_id=NEW.company_id)
 THEN RAISE EXCEPTION 'Lead does not belong to this company'; END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS verify_estimate_company ON public.move_estimates;
CREATE TRIGGER verify_estimate_company BEFORE INSERT OR UPDATE ON public.move_estimates
FOR EACH ROW EXECUTE FUNCTION public.verify_moveflow_lead_company();
DROP TRIGGER IF EXISTS verify_job_company ON public.move_jobs;
CREATE TRIGGER verify_job_company BEFORE INSERT OR UPDATE ON public.move_jobs
FOR EACH ROW EXECUTE FUNCTION public.verify_moveflow_lead_company();
ALTER TABLE public.move_estimates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.move_jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.move_estimates, public.move_jobs FROM anon;
GRANT SELECT, INSERT, UPDATE ON public.move_estimates, public.move_jobs TO authenticated;
-- Existing policies, if any, should be audited before installation.
DROP POLICY IF EXISTS "Members read estimates" ON public.move_estimates;
DROP POLICY IF EXISTS "Members insert estimates" ON public.move_estimates;
DROP POLICY IF EXISTS "Members update estimates" ON public.move_estimates;
DROP POLICY IF EXISTS "Members read jobs" ON public.move_jobs;
DROP POLICY IF EXISTS "Members insert jobs" ON public.move_jobs;
DROP POLICY IF EXISTS "Members update jobs" ON public.move_jobs;
CREATE POLICY "Members read estimates" ON public.move_estimates FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.company_members m WHERE m.company_id=move_estimates.company_id AND m.user_id=(SELECT auth.uid())));
CREATE POLICY "Members insert estimates" ON public.move_estimates FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM public.company_members m WHERE m.company_id=move_estimates.company_id AND m.user_id=(SELECT auth.uid())));
CREATE POLICY "Members update estimates" ON public.move_estimates FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM public.company_members m WHERE m.company_id=move_estimates.company_id AND m.user_id=(SELECT auth.uid())))
WITH CHECK (EXISTS (SELECT 1 FROM public.company_members m WHERE m.company_id=move_estimates.company_id AND m.user_id=(SELECT auth.uid())));
CREATE POLICY "Members read jobs" ON public.move_jobs FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.company_members m WHERE m.company_id=move_jobs.company_id AND m.user_id=(SELECT auth.uid())));
CREATE POLICY "Members insert jobs" ON public.move_jobs FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM public.company_members m WHERE m.company_id=move_jobs.company_id AND m.user_id=(SELECT auth.uid())));
CREATE POLICY "Members update jobs" ON public.move_jobs FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM public.company_members m WHERE m.company_id=move_jobs.company_id AND m.user_id=(SELECT auth.uid())))
WITH CHECK (EXISTS (SELECT 1 FROM public.company_members m WHERE m.company_id=move_jobs.company_id AND m.user_id=(SELECT auth.uid())));
COMMIT;
