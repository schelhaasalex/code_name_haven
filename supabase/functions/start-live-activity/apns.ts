// Talking to Apple's push service: the signed token that says who's asking,
// and the push that starts a Live Activity.
//
// Web standards only — crypto.subtle, fetch, TextEncoder — so it runs the same
// in Supabase's Deno and in Node, where `apns.test.ts` checks it against a key
// openssl made.

export type Environment = "sandbox" | "production";

export interface ApnsKey {
  /** The .p8 file's contents: "-----BEGIN PRIVATE KEY----- ..." */
  p8: string;
  /** The key's id in the developer account, ten characters. */
  keyId: string;
  /** The team that owns the app, ten characters. */
  teamId: string;
}

export interface LiveActivityStart {
  /** The app's bundle id. Apple routes on `<bundle>.push-type.liveactivity`. */
  bundleId: string;
  /** The attributes type's Swift name, exactly. */
  attributesType: string;
  /** Already encoded by the phone, as ActivityKit will decode them. */
  attributes: unknown;
  contentState: unknown;
  /** Required by Apple for a start. No sound: nothing buzzes during an evening. */
  alert: { title: string; body: string };
}

const host: Record<Environment, string> = {
  sandbox: "https://api.sandbox.push.apple.com",
  production: "https://api.push.apple.com",
};

function base64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pkcs8(p8: string): Uint8Array {
  const body = p8.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

/**
 * The bearer token Apple asks for: ES256 over the key id and the team, good
 * for an hour. WebCrypto signs ECDSA as r‖s already, which is what a JWT wants.
 */
export async function apnsToken(key: ApnsKey, now = Math.floor(Date.now() / 1000)): Promise<string> {
  const enc = new TextEncoder();
  const header = base64url(enc.encode(JSON.stringify({ alg: "ES256", kid: key.keyId })));
  const claims = base64url(enc.encode(JSON.stringify({ iss: key.teamId, iat: now })));
  const signing = `${header}.${claims}`;
  const privateKey = await crypto.subtle.importKey(
    "pkcs8", pkcs8(key.p8), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, privateKey, enc.encode(signing));
  return `${signing}.${base64url(new Uint8Array(signature))}`;
}

/** The whole request for one device, without sending it. */
export function startRequest(
  start: LiveActivityStart, token: string, environment: Environment, bearer: string,
  now = Math.floor(Date.now() / 1000),
): { url: string; init: RequestInit } {
  const payload = {
    aps: {
      timestamp: now,
      event: "start",
      "attributes-type": start.attributesType,
      attributes: start.attributes,
      "content-state": start.contentState,
      alert: { title: start.alert.title, body: start.alert.body },
    },
  };
  return {
    url: `${host[environment]}/3/device/${token}`,
    init: {
      method: "POST",
      headers: {
        authorization: `bearer ${bearer}`,
        "apns-topic": `${start.bundleId}.push-type.liveactivity`,
        "apns-push-type": "liveactivity",
        "apns-priority": "10",
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    },
  };
}

/**
 * Apple's answer, reduced to what the caller does next. A token Apple no
 * longer knows is one to forget; anything else is a failure to report.
 */
export function outcome(status: number, reason?: string): "sent" | "forget" | "failed" {
  if (status === 200) return "sent";
  if (status === 410 || reason === "BadDeviceToken" || reason === "Unregistered") return "forget";
  return "failed";
}
