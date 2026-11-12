# MoveFlow AI automation deployment checklist

The repository now includes a company-registration page, a database migration and a lead-routing Edge Function **source file**. They are not automatically deployed to Supabase by committing to GitHub.

## Status
- Live: GitHub Pages website, authentication starter, dashboard starter, company setup page (after GitHub Pages publish).
- Not deployed: SQL migration, route-lead Edge Function.
- Not built yet: public quote form integration, Turnstile widget, automatic email notifications, subscriptions/billing, onboarding approvals UI, company self-service ZIP coverage, operational monitoring and backup automation.
- Existing Google Form still handles the public quote link and is not connected to the routing function.
- **Do not process real customer leads through the new system until tested.**

## Activate company registration
1. Supabase > SQL Editor > New query.
2. Copy contents of `supabase/migrations/20261112_company_onboarding.sql` and review.
3. Run the SQL once. It adds authenticated company onboarding and a restricted lead-status update function.
4. Test with a non-production account at `/company-setup/`.
5. Company records are created inactive. Activate only after verifying the business.

## Lead routing deployment (requires developer setup)
1. Configure Supabase CLI and deploy `supabase/functions/route-lead/index.ts` as `route-lead` with `--no-verify-jwt` (public endpoint protected by Turnstile).
2. Add Cloudflare Turnstile to the quote form and configure `TURNSTILE_SECRET_KEY` in Supabase Edge Function secrets. Never expose secret keys in HTML.
3. Keep `ROUTING_ENABLED` unset or false until end-to-end testing is complete.
4. Build and connect the website quote form to the deployed function, passing the Turnstile response token.
5. Add and verify moving companies and service-area ZIP codes, then test company-specific and general leads.
6. Add rate limits, alerting, duplicate detection, privacy notices, deletion/retention policy, and secure email notification integration before real-world use.
7. Set `ROUTING_ENABLED=true` only when the complete workflow passes security and operational testing.

## Known limits of current starter routing
- General leads are distributed deterministically among active companies covering the pickup ZIP, not based on capacity or true round-robin.
- No matching company returns a no-coverage message, not an admin queue.
- No automated email notification or payment collection.
- No admin approval interface; company activation currently requires a trusted Supabase administrator.
- Browser-side origin checks are not authentication; Turnstile plus further rate limiting are essential.
- The database migration restricts lead status changes but does not implement an audit trail.
- Database exports and disaster recovery still need a separate process.

## Backups
- Initial schema: `moveflow_database_setup.sql`.
- Current migration: `supabase/migrations/20261112_company_onboarding.sql`.
- Repository ZIP: https://github.com/MoveFlowAi/moveflow-ai/archive/refs/heads/main.zip
- GitHub is not a backup of Supabase customer records. Back those up separately and privately.
