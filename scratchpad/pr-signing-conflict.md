## Stop naming a signing identity: automatic signing picks it

> Reclaim has conflicting provisioning settings. Reclaim is automatically signed
> for development, but a conflicting code signing identity Apple Distribution has
> been manually specified.

Both targets, every archive.

The line it names was added to get around *"Your team has no devices..."* — a
different problem with a different answer: register a device. An Apple-silicon
Mac counts, as "My Mac (Designed for iPhone)". That was done, and this was left
behind, where all it can do is argue with the profile automatic signing chose.

Nothing replaces it. Xcode signs the archive with Apple Development and re-signs
it for distribution on the way out, which is what the Organizer's **Distribute
App** step is for. The comment in its place says why there is no identity there,
so it doesn't come back.

### Verified by archiving, not by reading

`xcodebuild archive` → **ARCHIVE SUCCEEDED**, signed by `Apple Development: Alex
Schelhaas`, and the entitlements in the `.xcarchive` are the ones that should be
there:

```
com.apple.developer.nfc.readersession.formats  ["TAG"]      ← the 90778 fix
com.apple.security.application-groups          ["group.com.alexschelhaas.reclaim"]
com.apple.developer.associated-domains         ["applinks:haven-links-lime.vercel.app"]
com.apple.developer.applesignin                ["Default"]
```

🤖 Generated with [Claude Code](https://claude.com/claude-code)
