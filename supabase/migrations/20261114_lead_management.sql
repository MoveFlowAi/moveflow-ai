-- MoveFlow AI: scoped lead updates and private company notes.
-- Review on a staging project before running in production.
-- Does not modify existing leads or company memberships.
BEGIN;
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS internal_notes text;
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
-- Restrict browser-side updates to only the two editable fields.
REVOKE UPDATE ON public.leads FROM anon, authenticated;
GRANT UPDATE (status, internal_notes) ON public.leads TO authenticated;
DROP POLICY IF EXISTS "Company members update their leads" ON public.leads;
CREATE POLICY "Company members update their leads"
ON public.leads FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.company_members m
    WHERE m.company_id = leads.company_id AND m.user_id = (SELECT auth.uid())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.company_members m
    WHERE m.company_id = leads.company_id AND m.user_id = (SELECT auth.uid())
  )
);
COMMIT;
-- Verify: test as two distinct authenticated companies.
-- Note: SQL column privileges restrict updates, while RLS restricts rows.
