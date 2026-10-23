// The Live Activity push, checked without Apple: a throwaway P-256 key made
// by openssl (the kind of key Apple issues as a .p8), a token signed with it,
// and the signature verified with the matching public key.
//
//   node --test supabase/tests/apns.test.ts

import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { apnsToken, outcome, startRequest } from "../functions/start-live-activity/apns.ts";

const dir = mkdtempSync(join(tmpdir(), "apns-"));
execFileSync("openssl", ["genpkey", "-algorithm", "EC", "-pkeyopt", "ec_paramgen_curve:P-256",
  "-out", join(dir, "key.p8")]);
execFileSync("openssl", ["pkey", "-in", join(dir, "key.p8"), "-pubout", "-out", join(dir, "pub.pem")]);
const p8 = readFileSync(join(dir, "key.p8"), "utf8");
const pub = readFileSync(join(dir, "pub.pem"), "utf8");

const fromB64url = (s: string) => Buffer.from(s.replace(/-/g, "+").replace(/_/g, "/"), "base64");

test("the token is ES256 over the key id and team, and verifies with the key's public half", async () => {
  const token = await apnsToken({ p8, keyId: "ABC123DEFG", teamId: "73TQJ9R77A" }, 1_800_000_000);
  const [h, c, s] = token.split(".");
  assert.deepEqual(JSON.parse(fromB64url(h).toString()), { alg: "ES256", kid: "ABC123DEFG" });
  assert.deepEqual(JSON.parse(fromB64url(c).toString()), { iss: "73TQJ9R77A", iat: 1_800_000_000 });
  assert.equal(fromB64url(s).length, 64, "a JWT wants r‖s, 64 bytes, not DER");

  const spki = fromB64url(pub.replace(/-----[^-]+-----/g, "").replace(/\s+/g, ""));
  const key = await crypto.subtle.importKey("spki", spki, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
  const ok = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key,
    fromB64url(s), new TextEncoder().encode(`${h}.${c}`));
  assert.ok(ok, "the signature verifies");
});

test("a start is a liveactivity push to the bundle's liveactivity topic, with no sound", () => {
  const { url, init } = startRequest({
    bundleId: "com.alexschelhaas.reclaim",
    attributesType: "ReclaimActivityAttributes",
    attributes: { gatheringId: "D0DF523F-E265-492D-92DC-512D285CAFF3" },
    contentState: { startedAt: 783_000_000, memberCount: 1, placeName: "Low Vole" },
    alert: { title: "t", body: "b" },
  }, "abcd", "production", "BEARER", 1_800_000_000);

  assert.equal(url, "https://api.push.apple.com/3/device/abcd");
  const headers = init.headers as Record<string, string>;
  assert.equal(headers["apns-topic"], "com.alexschelhaas.reclaim.push-type.liveactivity");
  assert.equal(headers["apns-push-type"], "liveactivity");
  assert.equal(headers.authorization, "bearer BEARER");

  const aps = JSON.parse(init.body as string).aps;
  assert.equal(aps.event, "start");
  assert.equal(aps.timestamp, 1_800_000_000);
  assert.equal(aps["attributes-type"], "ReclaimActivityAttributes");
  assert.deepEqual(aps["content-state"], { startedAt: 783_000_000, memberCount: 1, placeName: "Low Vole" });
  assert.equal(aps.sound, undefined, "nothing buzzes during an evening");
  assert.equal(aps.alert.sound, undefined);
});

test("sandbox goes to Apple's sandbox", () => {
  const { url } = startRequest({ bundleId: "b", attributesType: "A", attributes: {}, contentState: {},
    alert: { title: "", body: "" } }, "ff", "sandbox", "x");
  assert.equal(url, "https://api.sandbox.push.apple.com/3/device/ff");
});

test("a token Apple no longer knows is forgotten; other failures are reported", () => {
  assert.equal(outcome(200), "sent");
  assert.equal(outcome(410, "Unregistered"), "forget");
  assert.equal(outcome(400, "BadDeviceToken"), "forget");
  assert.equal(outcome(403, "InvalidProviderToken"), "failed");
  assert.equal(outcome(500), "failed");
});
