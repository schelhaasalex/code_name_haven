<!-- Base branch: `staging`, unless this IS the promotion of staging to main.
     Nothing else reaches main; a pull request that tries is failed by CI. -->

## What this changes

<!-- One or two sentences. What someone using the app would notice, or what a
     future reader needs to know about the shape of the code. -->

## Why

<!-- The problem, not the solution. If it fixes something that was silently
     wrong, say what would have gone wrong and when it would have shown up. -->

---

## The rules

These are the ones that get broken quietly. Tick what applies; delete what
doesn't. `CLAUDE.md` has the reasoning behind each.

- [ ] **No new user-facing string is hardcoded.** Everything went into
      `copy/strings.json`, keyed `screen.element`.
- [ ] **Nothing reads another person's rows.** Anything crossing a person
      boundary goes through an RPC returning an aggregate — no widened policy,
      no direct table read.
- [ ] **Nothing shows absence.** No screen names someone who hasn't acted, or
      counts down toward a number of people the app cannot know.
- [ ] **Nothing is gated on a sensor, permission or network call.** A session
      still counts with the phone in a pocket, the place unnamed, and nobody
      else there.
- [ ] **No required setup was added.**
- [ ] **The knowledge test passes on every new string** — what does the app
      actually know, and when did it learn it?

- [ ] **`scripts/shape.sh` passes.** One view per file, no hardcoded strings,
      no literal colours, every copy key real. CI runs it too.

## Database changes

- [ ] Not applicable
- [ ] `supabase/tests/run.sh` passes (21 assertions)
- [ ] New tables revoke Supabase's default `GRANT ALL` from `anon` and
      `authenticated`, then grant deliberately
- [ ] New client-facing functions have a wrapper in `public` (PostgREST doesn't
      serve the `app` schema)
- [ ] Applied to the hosted project, and `get_advisors` comes back clean

## Checked how

<!-- What you actually ran, not what you intended to. "Builds and the previews
     render" is a real answer. "Ran the schema tests, 16 pass" is a better one.
     If you couldn't verify something, say which part. -->

## Voice

<!-- Only if this adds or changes copy. Would it feel at home on a nice kitchen
     appliance? Never a raw stat with no warmth, never exclamation-point
     cheeriness, never guilt, never what was missed. -->
