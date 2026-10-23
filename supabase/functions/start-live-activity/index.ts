// Put a phone's Live Activity on its lock screen, for an evening it started
// in the background.
//
// The phone calls this right after the box woke it and it started an evening
// — iOS wouldn't let it show the Live Activity itself, asleep in a drawer.
// It sends the activity already encoded (ActivityKit decodes what the phone's
// own encoder wrote), and the words for the alert Apple requires (copy lives
// in strings.json, not here). This checks the person really is in that
// evening, then pushes to every device they've registered.
//
// Secrets, set in the dashboard (Edge Functions → Secrets), never in git:
//   APNS_KEY_P8   the .p8 file's contents
//   APNS_KEY_ID   its key id
//   APNS_TEAM_ID  73TQJ9R77A
//   APNS_TOPIC    com.alexschelhaas.reclaim
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY Supabase provides itself.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { apnsToken, type Environment, outcome, startRequest } from "./apns.ts";

const env = (name: string) => {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not set`);
  return value;
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "POST only" });

  const admin = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));
  const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: { user } } = await admin.auth.getUser(jwt);
  if (!user) return json(401, { error: "not signed in" });

  let body: {
    gatheringId?: string;
    attributes?: { gatheringId?: string };
    contentState?: Record<string, unknown>;
    alert?: { title?: string; body?: string };
  };
  try { body = await req.json(); } catch { return json(400, { error: "not JSON" }); }

  const gathering = (body.gatheringId ?? "").toLowerCase();
  if (!gathering || (body.attributes?.gatheringId ?? "").toLowerCase() !== gathering || !body.contentState) {
    return json(400, { error: "gatheringId, attributes and contentState, agreeing" });
  }

  // Only an evening you are in right now. Anything else would let a phone put
  // whatever it liked on its own lock screen under the app's name — harmless,
  // but not what this is for.
  const { data: live } = await admin.from("sessions").select("id")
    .eq("profile_id", user.id).eq("gathering_id", gathering).is("ended_at", null).limit(1);
  if (!live?.length) return json(409, { error: "not in that evening" });

  const { data: tokens } = await admin.from("activity_tokens").select("token, environment")
    .eq("profile_id", user.id);
  if (!tokens?.length) return json(200, { sent: 0, note: "no device has registered" });

  const bearer = await apnsToken({
    p8: env("APNS_KEY_P8"), keyId: env("APNS_KEY_ID"), teamId: env("APNS_TEAM_ID"),
  });
  const start = {
    bundleId: env("APNS_TOPIC"),
    attributesType: "ReclaimActivityAttributes",
    attributes: body.attributes,
    contentState: body.contentState,
    alert: { title: String(body.alert?.title ?? "").slice(0, 120), body: String(body.alert?.body ?? "").slice(0, 240) },
  };

  let sent = 0;
  const failures: string[] = [];
  for (const { token, environment } of tokens) {
    const { url, init } = startRequest(start, token, environment as Environment, bearer);
    const res = await fetch(url, init);
    const reason = res.status === 200 ? undefined : (await res.json().catch(() => ({})))?.reason;
    switch (outcome(res.status, reason)) {
      case "sent": sent++; break;
      case "forget": await admin.from("activity_tokens").delete().eq("token", token); break;
      case "failed": failures.push(`${res.status} ${reason ?? ""}`.trim());
    }
  }
  return json(200, { sent, failures });
});
