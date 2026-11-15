# MoveFlow AI — Stripe Sandbox setup (NOT LIVE)
Checkout UI and Edge Functions are committed to GitHub, but NOT deployed or connected to Stripe yet.

## 1. Database
Back up your Supabase project and review the existing schema/policies in staging. Apply in order:
1. `20261114_lead_management.sql`
2. `20261114_operations.sql`
3. `20261114_plan_entitlements.sql`
4. `20261114_feature_gates.sql`
5. `20261114_stripe_billing.sql`

Do not assume a GitHub commit executes a migration.

## 2. Supabase Edge Functions
Using the Supabase CLI in the project root with an authenticated account:
```sh
supabase link --project-ref jmatopczikrdrooxrtfy
supabase functions deploy billing-checkout
supabase functions deploy billing-webhook --no-verify-jwt
```
The webhook MUST accept unsigned JWT requests from Stripe, but verifies Stripe's own signature. The checkout function requires a signed-in Supabase session.

## 3. Configure secrets securely
In Supabase project settings → Edge Functions → Secrets, set:
- `STRIPE_SECRET_KEY` = sandbox secret key beginning with `sk_test_`
- `STRIPE_WEBHOOK_SECRET` = signing secret `whsec_...` from the webhook destination
- Ensure `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are present in the Edge Function environment.

**Never put secrets into GitHub, frontend HTML, screenshots, or chat.** Do not share any secret values with the assistant.

## 4. Stripe sandbox webhook
Stripe Dashboard → Developers → Webhooks (or Workbench → Webhooks) → Add destination:
`https://jmatopczikrdrooxrtfy.supabase.co/functions/v1/billing-webhook`

Subscribe to:
- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`

Use the destination signing secret as `STRIPE_WEBHOOK_SECRET`. Test webhook delivery and check Supabase function logs.

## 5. Price mapping (sandbox only)
| Plan | Monthly | Yearly |
|---|---|---|
| Starter | price_1Ubsi836Vtq8lcaCvPvClPPs | price_1Ubt3f36Vtq8lcaC8ljwntqw |
| Growth | price_1Ubsmg36Vtq8lcaCnpQZYh32 | price_1Ubt4G36Vtq8lcaCYoD8bW0P |
| Premium | price_1UbspP36Vtq8lcaCBmpYPojT | price_1Ubt4f36Vtq8lcaCSB5jsNi9 |

## 6. Test before production
- Create a separate approved test company, sign in, open Dashboard → Settings → Subscription & billing.
- Select Starter/monthly, complete checkout using Stripe's test payment method.
- Confirm the Stripe webhook was received and `company_plan_assignments` becomes active.
- Verify Starter cannot access estimates or jobs, Growth can access estimates only, and Premium can access both.
- Verify Company A cannot read or update Company B's data, even by calling the REST API directly.
- Test monthly and yearly variants, cancellations, failed payments, billing portal, duplicate checkout attempts, and webhook retries.
- Ensure no secret keys are embedded in the public GitHub Pages site.
- Check actual Stripe price amounts and intervals against the configured IDs.

## Important limitations
- These functions are **sandbox-only** and reject live Stripe secret keys.
- The billing portal may require setup in Stripe Dashboard before use.
- The company approval step still requires administrator action.
- This version does not include a complete owner admin dashboard, automatic company approval, production billing, invoice tax handling, or email/SMS notifications.
- Do not switch to live Stripe until security and billing testing are complete.
