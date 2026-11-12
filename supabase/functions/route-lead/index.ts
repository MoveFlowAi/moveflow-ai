// Supabase Edge Function: route-lead/index.ts
// Deploy with: supabase functions deploy route-lead --no-verify-jwt
// Set TURNSTILE_SECRET_KEY and ROUTING_ENABLED=true only after testing.
// Set up Cloudflare Turnstile on the public form before enabling.
import { createClient } from "npm:@supabase/supabase-js@2";
const origin = "https://moveflowai.github.io";
const cors = {"Access-Control-Allow-Origin":origin,"Access-Control-Allow-Headers":"content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"content-type":"application/json"}});
Deno.serve(async req=>{
 if(req.method==="OPTIONS")return new Response(null,{headers:cors});
 if(req.method!=="POST")return json({error:"Method not allowed"},405);
 if(req.headers.get("origin")!==origin)return json({error:"Invalid origin"},403);
 if(Deno.env.get("ROUTING_ENABLED")!=="true")return json({error:"Lead intake is not activated yet"},503);
 try{
  const body=await req.json();
  const {name,email,pickup_zip,destination_zip,move_date,company,turnstile_token}=body;
  if(typeof name!=="string"||name.trim().length<2||name.length>120||
     typeof email!=="string"||!/^\S+@\S+\.\S+$/.test(email)||email.length>254||
     typeof pickup_zip!=="string"||!/^\d{5}$/.test(pickup_zip)||
     (destination_zip && (typeof destination_zip!=="string"||!/^\d{5}$/.test(destination_zip)))||
     (company && (typeof company!=="string"||!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(company)))||
     (move_date && (typeof move_date!=="string"||!/^\d{4}-\d{2}-\d{2}$/.test(move_date))))
   return json({error:"Invalid form details"},400);
  const secret=Deno.env.get("TURNSTILE_SECRET_KEY");
  if(!secret||typeof turnstile_token!=="string")return json({error:"Verification unavailable"},503);
  const verification=await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify",{
    method:"POST",headers:{"content-type":"application/x-www-form-urlencoded"},
    body:new URLSearchParams({secret,response:turnstile_token})
  });
  const result=await verification.json();
  if(!result.success)return json({error:"Verification failed"},403);
  const url=Deno.env.get("SUPABASE_URL")!;
  const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const db=createClient(url,serviceKey,{auth:{persistSession:false}});
  let companyId:string|undefined;
  if(company){
   const {data,error}=await db.from("companies").select("id").eq("slug",company).eq("active",true).maybeSingle();
   if(error)throw error;
   if(!data)return json({error:"Company not available"},404);
   companyId=data.id;
  }else{
   const {data:areas,error}=await db.from("service_areas").select("company_id").eq("zip_code",pickup_zip).limit(100);
   if(error)throw error;
   const ids=[...new Set((areas??[]).map(x=>x.company_id))];
   if(!ids.length)return json({error:"No participating moving company serves this ZIP code yet"},422);
   const {data:eligible,error:eligibleError}=await db.from("companies").select("id").eq("active",true).in("id",ids);
   if(eligibleError)throw eligibleError;
   if(!eligible?.length)return json({error:"No active moving company serves this ZIP code yet"},422);
   // Deterministic selection for the starter version; use atomic round-robin in production.
   const sorted=eligible.map(x=>x.id).sort();
   const index=[...pickup_zip].reduce((a,c)=>a+Number(c),0)%sorted.length;
   companyId=sorted[index];
  }
  const {error}=await db.from("leads").insert({
   company_id:companyId,customer_name:name.trim(),customer_email:email.trim(),
   pickup_zip,destination_zip:destination_zip||null,move_date:move_date||null
  });
  if(error)throw error;
  return json({ok:true,message:"Your request was submitted."},201);
 }catch(e){console.error("Lead routing failed",e);return json({error:"Unable to submit request"},500)}
});
