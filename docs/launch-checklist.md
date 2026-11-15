# MoveFlow AI launch checklist (November 2026)
## Implemented in repository
- Public quote form and Supabase Edge Function routing (tested with a demo lead).
- Company registration and authentication (tested with a demo company).
- Dashboard lead search, status, CSV export, and internal notes (notes migration pending).
- Draft estimates and scheduled jobs (operations migration pending).
- Read-only subscription plan assignments schema (migration pending; no billing).
## Deployment steps
1. Backup the Supabase database and review existing table schema, triggers, and RLS policies.
2. Apply `20261114_lead_management.sql` in staging, then `20261114_operations.sql`, then `20261114_plan_entitlements.sql`. Review each with the actual schema before production.
3. Test with two separate company accounts: Company A cannot read or change Company B leads, estimates, jobs, or plan data.
4. Test a lead status edit, internal note, draft estimate, and scheduled job. Check failures and error messages.
5. Confirm GitHub Pages deploys the latest dashboard and that onboarding, auth, and quote forms work on mobile.
6. Confirm the public quote form handles inactive companies, ZIP routing, bot checks, consent, and errors.
## Not implemented yet
- Sending estimates by email or SMS; acceptance flow; calendar integrations.
- Stripe subscriptions, webhooks, billing portal, cancellation and upgrade flows.
- Server-enforced feature limits per paid tier; plan assignment table alone does not enforce feature access.
- Automated company approval, staff invitations and role separation, production audit logs.
- Privacy policy, terms, retention/deletion workflow, monitoring, backups, accessibility and security review.
## Billing security design
Never trust a client-supplied plan name or payment status. A verified Stripe webhook should update plan assignments server-side using a protected service credential. Every premium action must check a server-enforced entitlement, not merely hide buttons. Never put Stripe secret keys or Supabase service-role keys in GitHub Pages JavaScript.
