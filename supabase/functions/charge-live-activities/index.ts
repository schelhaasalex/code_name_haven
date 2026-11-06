// The evening charges: once a minute, push each running Live Activity the
// step it hasn't shown yet — the next segment of the ring, a light for
// someone who joined, or the end of an evening the person has left.
//
// Called by the 'charge-live-activities' pg_cron job (migration 0016), not by
// a phone, so there is no JWT to check. The job sends the key it keeps in
// Vault, and claim_charges refuses anything else: a stranger calling this
// address gets an error, and nothing is sent.
//
// What is due is decided in the database, where it's tested; this only
// carries it to Apple. Secrets as start-live-activity's.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { apnsToken, changeRequest, type Environment, outcome } from "../_shared/apns.ts";

const env = (name: string) => {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not set`);
  return value;
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

type Due = { token: string; environment: Environment; event: "update" | "end"; state: unknown };

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "POST only" });

  const admin = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));
  const { data, error } = await admin.rpc("claim_charges", { p_key: req.headers.get("x-charge-key") });
  if (error) return json(403, { error: "not the minute's job" });

  const due = (data ?? []) as Due[];
  if (!due.length) return json(200, { sent: 0 });

  const bearer = await apnsToken({
    p8: env("APNS_KEY_P8"), keyId: env("APNS_KEY_ID"), teamId: env("APNS_TEAM_ID"),
  });

  let sent = 0;
  const failures: string[] = [];
  for (const { token, environment, event, state } of due) {
    const { url, init } = changeRequest(env("APNS_TOPIC"), event, state, token, environment, bearer);
    const res = await fetch(url, init);
    const reason = res.status === 200 ? undefined : (await res.json().catch(() => ({})))?.reason;
    switch (outcome(res.status, reason)) {
      case "sent": sent++; break;
      case "forget": await admin.rpc("forget_live_activity", { p_token: token }); break;
      case "failed": failures.push(`${event} ${res.status} ${reason ?? ""}`.trim());
    }
  }
  if (failures.length) console.log("charge failures", failures);
  return json(200, { sent, failures });
});
