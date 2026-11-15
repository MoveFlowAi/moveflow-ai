import Stripe from "npm:stripe@17.7.0";
import { createClient } from "npm:@supabase/supabase-js@2";
const origin="https://moveflowai.github.io";
const headers={"Access-Control-Allow-Origin":origin,"Access-Control-Allow-Headers":"authorization,apikey,content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const respond=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...headers,"Content-Type":"application/json"}});
const prices:Record<string,string>={
 starter_month:"price_1Ubsi836Vtq8lcaCvPvClPPs",
 starter_year:"price_1Ubt3f36Vtq8lcaC8ljwntqw",
 growth_month:"price_1Ubsmg36Vtq8lcaCnpQZYh32",
 growth_year:"price_1Ubt4G36Vtq8lcaCYoD8bW0P",
 premium_month:"price_1UbspP36Vtq8lcaCBmpYPojT",
 premium_year:"price_1Ubt4f36Vtq8lcaCSB5jsNi9"
};
Deno.serve(async req=>{
 if(req.method==="OPTIONS")return new Response(null,{headers});
 if(req.method!=="POST")return respond({error:"Method not allowed"},405);
 if(req.headers.get("origin")!==origin)return respond({error:"Invalid origin"},403);
 const stripeKey=Deno.env.get("STRIPE_SECRET_KEY");
 if(!stripeKey||!stripeKey.startsWith("sk_test_"))return respond({error:"Sandbox billing is not configured"},503);
 try{
  const token=req.headers.get("Authorization")?.replace(/^Bearer\s+/i,"");
  if(!token)return respond({error:"Sign in required"},401);
  const url=Deno.env.get("SUPABASE_URL")!,service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const db=createClient(url,service,{auth:{persistSession:false}});
  const {data:{user},error:authError}=await db.auth.getUser(token);
  if(authError||!user)return respond({error:"Invalid session"},401);
  const body=await req.json();
  const companyId=body?.company_id,action=body?.action;
  if(typeof companyId!=="string"||!/^[0-9a-f-]{36}$/i.test(companyId))return respond({error:"Invalid company"},400);
  const {data:member,error:memberError}=await db.from("company_members").select("company_id").eq("company_id",companyId).eq("user_id",user.id).maybeSingle();
  if(memberError||!member)return respond({error:"Company access denied"},403);
  const {data:company}=await db.from("companies").select("id,active").eq("id",companyId).maybeSingle();
  if(!company?.active)return respond({error:"Company approval required"},403);
  const stripe=new Stripe(stripeKey,{apiVersion:"2024-06-20"});
  const {data:customerRow,error:customerError}=await db.from("moveflow_billing_customers").select("stripe_customer_id").eq("company_id",companyId).maybeSingle();
  if(customerError)throw customerError;
  let customerId=customerRow?.stripe_customer_id as string|undefined;
  if(action==="portal"){
   if(!customerId)return respond({error:"No billing account yet"},404);
   const portal=await stripe.billingPortal.sessions.create({customer:customerId,return_url:origin+"/moveflow-ai/dashboard/"});
   return respond({url:portal.url});
  }
  if(action!=="checkout"||typeof body.price_key!=="string"||!prices[body.price_key])return respond({error:"Invalid plan"},400);
  if(!customerId){
   const customer=await stripe.customers.create({email:user.email,metadata:{company_id:companyId}});
   customerId=customer.id;
   const {error:insertError}=await db.from("moveflow_billing_customers").insert({company_id:companyId,stripe_customer_id:customerId});
   if(insertError){
    const {data:existing}=await db.from("moveflow_billing_customers").select("stripe_customer_id").eq("company_id",companyId).maybeSingle();
    if(!existing)throw insertError;
    customerId=existing.stripe_customer_id;
   }
  }
  const subscriptions=await stripe.subscriptions.list({customer:customerId,status:"all",limit:100});
  if(subscriptions.data.some(s=>["active","trialing","past_due","unpaid","incomplete","paused"].includes(s.status)))
   return respond({error:"Existing subscription found. Use Manage billing to change plans."},409);
  const session=await stripe.checkout.sessions.create({
   mode:"subscription",customer:customerId,line_items:[{price:prices[body.price_key],quantity:1}],
   client_reference_id:companyId,subscription_data:{metadata:{company_id:companyId}},
   success_url:origin+"/moveflow-ai/dashboard/?billing=success",
   cancel_url:origin+"/moveflow-ai/dashboard/?billing=cancel",
   allow_promotion_codes:true
  });
  return respond({url:session.url});
 }catch(e){console.error("billing checkout error",e);return respond({error:"Billing is temporarily unavailable"},500)}
});
