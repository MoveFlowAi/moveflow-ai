import Stripe from "npm:stripe@17.7.0";
import { createClient } from "npm:@supabase/supabase-js@2";
const pricePlans:Record<string,"starter"|"growth"|"premium">={
 "price_1Ubsi836Vtq8lcaCvPvClPPs":"starter",
 "price_1Ubt3f36Vtq8lcaC8ljwntqw":"starter",
 "price_1Ubsmg36Vtq8lcaCnpQZYh32":"growth",
 "price_1Ubt4G36Vtq8lcaCYoD8bW0P":"growth",
 "price_1UbspP36Vtq8lcaCBmpYPojT":"premium",
 "price_1Ubt4f36Vtq8lcaCSB5jsNi9":"premium"
};
Deno.serve(async req=>{
 if(req.method!=="POST")return new Response("Method not allowed",{status:405});
 const key=Deno.env.get("STRIPE_SECRET_KEY"),secret=Deno.env.get("STRIPE_WEBHOOK_SECRET");
 if(!key||!key.startsWith("sk_test_")||!secret)return new Response("Not configured",{status:503});
 const stripe=new Stripe(key,{apiVersion:"2024-06-20"});
 let event:Stripe.Event;
 try{
  const signature=req.headers.get("stripe-signature");
  if(!signature)throw Error("Missing signature");
  event=await stripe.webhooks.constructEventAsync(await req.text(),signature,secret);
 }catch(e){console.error("Invalid webhook",e);return new Response("Invalid signature",{status:400})}
 if(!["customer.subscription.created","customer.subscription.updated","customer.subscription.deleted","checkout.session.completed"].includes(event.type))return new Response("ok");
 const db=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false}});
 try{
  // Checkout completion triggers a fresh subscription fetch, never trust checkout metadata as payment proof.
  let subscriptionId:string|undefined;
  if(event.type==="checkout.session.completed"){
   const session=event.data.object as Stripe.Checkout.Session;
   subscriptionId=typeof session.subscription==="string"?session.subscription:session.subscription?.id;
  }else subscriptionId=(event.data.object as Stripe.Subscription).id;
  if(!subscriptionId)return new Response("ok");
  const subscription=await stripe.subscriptions.retrieve(subscriptionId);
  const customerId=typeof subscription.customer==="string"?subscription.customer:subscription.customer.id;
  const {data:customer,error:customerError}=await db.from("moveflow_billing_customers").select("company_id").eq("stripe_customer_id",customerId).maybeSingle();
  if(customerError)throw customerError;
  if(!customer){console.error("Unknown billing customer",customerId);return new Response("Customer not mapped",{status:500})}
  if(subscription.metadata.company_id && subscription.metadata.company_id!==customer.company_id)return new Response("Company mismatch",{status:400});
  const priceId=subscription.items.data[0]?.price.id;
  const plan=pricePlans[priceId];
  if(!plan)return new Response("Unknown subscription price",{status:400});
  const {error:upsertError}=await db.from("moveflow_billing_subscriptions").upsert({
   stripe_subscription_id:subscription.id,company_id:customer.company_id,stripe_customer_id:customerId,
   stripe_price_id:priceId,stripe_status:subscription.status,
   current_period_end:new Date(subscription.current_period_end*1000).toISOString(),updated_at:new Date().toISOString()
  });
  if(upsertError)throw upsertError;
  // Reconcile all subscriptions for the company, preventing stale event order from granting access.
  const all=await stripe.subscriptions.list({customer:customerId,status:"all",limit:100});
  const eligible=all.data.filter(s=>s.status==="active" && pricePlans[s.items.data[0]?.price.id]);
  const chosen=eligible.sort((a,b)=>b.created-a.created)[0];
  const nextPlan=chosen?pricePlans[chosen.items.data[0].price.id]:"starter";
  const status=chosen?"active":all.data.some(s=>s.status==="past_due")?"past_due":"canceled";
  const {error:planError}=await db.from("company_plan_assignments").upsert({
   company_id:customer.company_id,plan:nextPlan,billing_status:status,updated_at:new Date().toISOString()
  });
  if(planError)throw planError;
  return new Response("ok");
 }catch(e){console.error("Stripe webhook failed",e);return new Response("Retry later",{status:500})}
});
