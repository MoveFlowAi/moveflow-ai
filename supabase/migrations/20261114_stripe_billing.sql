-- Apply after plan_entitlements.sql; review in staging first.
BEGIN;
CREATE TABLE IF NOT EXISTS public.moveflow_billing_customers (
 company_id uuid PRIMARY KEY REFERENCES public.companies(id) ON DELETE CASCADE,
 stripe_customer_id text NOT NULL UNIQUE,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.moveflow_billing_subscriptions (
 stripe_subscription_id text PRIMARY KEY,
 company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
 stripe_customer_id text NOT NULL,
 stripe_price_id text NOT NULL,
 stripe_status text NOT NULL,
 current_period_end timestamptz,
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.moveflow_stripe_events (
 stripe_event_id text PRIMARY KEY,
 received_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.moveflow_billing_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moveflow_billing_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moveflow_stripe_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.moveflow_billing_customers,public.moveflow_billing_subscriptions,public.moveflow_stripe_events FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.moveflow_billing_subscriptions TO authenticated;
CREATE POLICY "Members see subscription" ON public.moveflow_billing_subscriptions FOR SELECT TO authenticated
USING (EXISTS(SELECT 1 FROM public.company_members m WHERE m.company_id=moveflow_billing_subscriptions.company_id AND m.user_id=(SELECT auth.uid())));
COMMIT;
