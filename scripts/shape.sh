#!/usr/bin/env bash
# Shape checks. Everything here is a rule from CLAUDE.md or docs/STYLE.md that
# can be decided by reading the text of a file — so it is decided by reading the
# text of a file, rather than by whoever reviews the diff remembering.
#
# No toolchain, no dependencies, no network. Runs in about a second.
#
#   scripts/shape.sh
#
# Every rule below was broken by this repository at least once, usually by the
# same person who wrote the rule.

set -uo pipefail
cd "$(dirname "$0")/.."

FAIL=0
note() { printf '\n\033[1m%s\033[0m\n' "$1"; }
bad()  { printf '  %s\n' "$1"; FAIL=1; }

APP_SWIFT=$(find Reclaim ReclaimWidgets -name '*.swift' 2>/dev/null | sort)
ALL_SWIFT=$(find Reclaim ReclaimWidgets ReclaimKit/Sources -name '*.swift' 2>/dev/null | sort)
VIEW_FILES=$(find Reclaim/Screens Reclaim/Components -name '*.swift' 2>/dev/null | sort)

# 1. Size. Not a style preference: a 400-line view is a file nobody re-reads
#    before adding to it, which is how it got to 400 lines.
MAX_LINES=220
note "File length (max $MAX_LINES lines)"
for f in $ALL_SWIFT; do
  n=$(grep -c '' "$f")
  [ "$n" -gt "$MAX_LINES" ] && bad "$f is $n lines — something in it has a name of its own"
done

# 2. One view per file, named for the file. The exception-free version, because
#    "unless they're variants of one idea" is not a rule a script can hold and
#    turned out not to be one a person holds either.
note "One view per file"
for f in $APP_SWIFT; do
  names=$(grep -o '^struct [A-Za-z0-9_]*' "$f" | awk '{print $2}')
  count=$(printf '%s' "$names" | grep -c . || true)
  base=$(basename "$f" .swift)
  if [ "$count" -gt 1 ]; then
    bad "$f declares $count top-level types: $(echo $names | tr '\n' ' ')"
  elif [ "$count" -eq 1 ] && [ "$names" != "$base" ]; then
    bad "$f declares $names — the file is named for the view it holds"
  fi
done

# 3. A component takes data, not AppState. This is what keeps it previewable in
#    isolation and stops it quietly acquiring behaviour.
note "Components take data, not AppState"
for f in $(find Reclaim/Components -name '*.swift' | sort); do
  grep -q 'AppState' "$f" && bad "$f reads AppState — pass it what it needs instead"
done

# 4. CLAUDE.md rule 2. The voice ships as a bundled fallback and is overridden
#    from Supabase; a string baked into a view can never be changed without an
#    App Store release. Previews are exempt — nobody ships a preview.
note "No hardcoded user-facing strings"
# Not just Text("…"): a string handed to Eyebrow, to a button's title, or to
# VoiceOver is read by a person too, and each of these got past an earlier
# version of this check.
hits=$(for f in $APP_SWIFT; do
  awk '/^#Preview/ { exit }
       /Text\("/ && !/Text\("\\\(/ { print FILENAME ":" FNR ":" $0; next }
       /Eyebrow\(text: *"/ || /accessibilityLabel\("/ || /Label\("/ { print FILENAME ":" FNR ":" $0; next }
       /(title|label|subtitle|message): *"[^"]/ { print FILENAME ":" FNR ":" $0; next }
       /(banner|alertMessage) *= *"/ { print FILENAME ":" FNR ":" $0 }' "$f"
done)
[ -n "$hits" ] && while IFS= read -r hit; do
  bad "$(echo "$hit" | sed 's/^[[:space:]]*//') — put it in copy/strings.json"
done <<< "$hits"

# 5. Colors and type come from ReclaimKit/Design. A hex in a view is a colour
#    that will drift from the one beside it.
note "No literal colors outside Design"
hits=$(grep -rn 'Color(hex:\|Color(red:\|Color(\.sRGB' $ALL_SWIFT | grep -v '/Design/')
[ -n "$hits" ] && while IFS= read -r hit; do
  bad "$(echo "$hit" | sed 's/^[[:space:]]*//') — put it on the Palette"
done <<< "$hits"

# 6. Every screen builds in a preview against PreviewRepository with no network.
#    The interruption screens are the ones that matter: 13, 14 and 20 are
#    unreachable at runtime without an auto-close, a broken rhythm or five
#    evenings.
note "Every view has a preview"
for f in $VIEW_FILES; do
  grep -qE ': View \{|: View$' "$f" || continue          # not ViewModifier
  grep -q '#Preview' "$f" || bad "$f declares a view with no #Preview"
done

# 7. A copy key that isn't in strings.json renders as ⟨key⟩ in development and
#    as an empty string to a person. The Swift tests check the file; they need a
#    simulator, and this doesn't.
note "Every copy key exists"
KEYS=$(mktemp); USED=$(mktemp)
grep -o '^  "[^"]*"' copy/strings.json | tr -d ' "' | sort -u > "$KEYS"
grep -rho 't("[a-z0-9._]*"' $ALL_SWIFT | sed 's/t("//; s/"//' | sort -u > "$USED"
grep -rho 'Copy\["[a-z0-9._]*"\]' $ALL_SWIFT | sed 's/Copy\["//; s/"\]//' | sort -u >> "$USED"
sort -u -o "$USED" "$USED"
while read -r key; do
  [ -n "$key" ] && ! grep -qx "$key" "$KEYS" && bad "$key is used in Swift and is not in copy/strings.json"
done < "$USED"
rm -f "$KEYS" "$USED"

# 8. The same file lives in two places — the editable one and the one the app
#    bundles. Keeping them identical is the whole job.
note "The bundled copy matches copy/strings.json"
cmp -s copy/strings.json ReclaimKit/Sources/ReclaimKit/Resources/strings.json \
  || bad "copy/strings.json and ReclaimKit/.../Resources/strings.json have drifted"

# 9. The launch screen's colour is Palette.bone written out a second time.
#    UIKit reads Info.plist before any Swift runs, so a launch screen genuinely
#    cannot ask the Palette — and two copies of one fact are free to disagree.
#    Before this pair existed the key was `UILaunchScreen: {}`, which means the
#    system background: white in light mode, BLACK in dark, and the app then cut
#    to paper. That cut is the first thing anyone sees.
note "The launch colour matches the paper ground"
LAUNCH=Reclaim/Resources/Assets.xcassets/LaunchBone.colorset/Contents.json
if [ ! -f "$LAUNCH" ]; then
  bad "$LAUNCH is missing — UILaunchScreen has nothing to point at"
elif ! grep -q 'UIColorName: *LaunchBone' project.yml; then
  bad "project.yml does not point UILaunchScreen at LaunchBone"
else
  bone=$(sed -n 's/.*bone[[:space:]]*=[[:space:]]*Color(hex:[[:space:]]*0x\([0-9A-Fa-f]\{6\}\)).*/\1/p' \
         ReclaimKit/Sources/ReclaimKit/Design/Palette.swift | head -1 | tr '[:lower:]' '[:upper:]')
  flat=$(tr -d ' \n' < "$LAUNCH")
  launch=""
  for part in red green blue; do
    launch="$launch$(printf '%s' "$flat" | sed -n "s/.*\"$part\":\"0x\([0-9A-Fa-f]\{2\}\)\".*/\1/p")"
  done
  launch=$(printf '%s' "$launch" | tr '[:lower:]' '[:upper:]')
  if [ ${#bone} -ne 6 ] || [ ${#launch} -ne 6 ]; then
    bad "couldn't read both colours (Palette.bone='$bone', LaunchBone='$launch')"
  elif [ "$bone" != "$launch" ]; then
    bad "LaunchBone is #$launch and Palette.bone is #$bone — the app will flash on launch"
  fi
fi

# 12. One domain, set once. Links are written onto tags and printed as codes,
#     and there's no real domain yet — a host written into Swift is one the
#     rename will miss. They go through `Links.domain` (LINK_DOMAIN in
#     project.yml), and so does the entitlement that lets them open the app.
note "Links use LINK_DOMAIN"
hardcoded=$(grep -nE '"https?://[A-Za-z0-9]' $ALL_SWIFT 2>/dev/null)
[ -n "$hardcoded" ] && bad "A link host is written into Swift — use Links.domain: $(echo "$hardcoded" | head -1)"
grep -q 'applinks:$(LINK_DOMAIN)' Reclaim/Reclaim.entitlements \
  || bad "Reclaim.entitlements should say applinks:\$(LINK_DOMAIN), not a literal domain"

# 13. places.join_secret_hash is granted to no client, so a read of every column
#     is refused outright — and the app took the refusal for "no places". It
#     was invisible until a real account made one: the place was created, and
#     then couldn't be found. Places are read by `Place.readableColumns`.
note "Places are read by named columns"
bare=$(grep -nE 'from\("places"\)[[:space:]]*\.select\(\)' $ALL_SWIFT 2>/dev/null)
[ -n "$bare" ] && bad "A bare select() on places is refused by the database — use Place.readableColumns: $(echo "$bare" | head -1)"

# 14. The phone in the box has to keep listening. A central that asks iOS to
#     restore it is one that expects to be woken in the background, and only
#     bluetooth-central lets that happen. Without it the connection to the box
#     goes quiet the moment the screen does — which is the moment the phone is
#     put in — and nothing says so.
note "A phone in the box keeps listening"
if grep -q 'CBCentralManagerOptionRestoreIdentifierKey' $ALL_SWIFT 2>/dev/null; then
  grep -qE 'UIBackgroundModes:.*bluetooth-central' project.yml \
    || bad "Something restores a Bluetooth central, but UIBackgroundModes has no bluetooth-central"
  grep -q 'NSBluetoothAlwaysUsageDescription' project.yml \
    || bad "Bluetooth is used with no NSBluetoothAlwaysUsageDescription — the app crashes on first use"
fi

# 15. A sheet nothing opens. `@State private var naming = false` and
#     `.sheet(isPresented: $naming)` were both there on screen 17, and nothing
#     anywhere set it to true — so "Name them" was a word printed on a card,
#     and tapping it did nothing at all. It builds, it previews, and the only
#     way to find it is to tap it on a phone.
note "Every sheet has something that opens it"
for f in $(find Reclaim -name '*.swift'); do
  for flag in $(grep -oE '(sheet|fullScreenCover)\(isPresented: \$[A-Za-z_][A-Za-z0-9_]*' "$f" \
                | sed 's/.*\$//' | sort -u); do
    grep -q "@State private var $flag" "$f" || continue   # a binding from elsewhere
    grep -qE "(^|[^.A-Za-z0-9_])$flag = true" "$f" \
      || bad "$f presents a sheet on \$$flag, and nothing ever sets $flag = true"
  done
done

# 16. The build number lives in an xcconfig, and a build setting written into
#     project.yml would silently win over it — so every upload after the first
#     would carry the same number, and App Store Connect would refuse it at
#     the end of an archive rather than at the start.
note "The build number is not written into the project"
# The key itself, not the $(CURRENT_PROJECT_VERSION) the Info.plist reads.
grep -qE '^[[:space:]]*CURRENT_PROJECT_VERSION:' project.yml \
  && bad "project.yml sets CURRENT_PROJECT_VERSION — it belongs in Config/Base.xcconfig, from scripts/generate.sh"
grep -q "CURRENT_PROJECT_VERSION" Config/Base.xcconfig \
  || bad "Config/Base.xcconfig should carry CURRENT_PROJECT_VERSION"

# 17. The box's lights are found over Bonjour, and iOS refuses to browse for a
#     service the app didn't list in NSBonjourServices — no error, no prompt,
#     just a box that never lights. The usage string is what the Local Network
#     prompt says; without it there is no prompt either.
note "The box's lights can be found"
if grep -q 'NWBrowser' $ALL_SWIFT 2>/dev/null; then
  svc=$(sed -n 's/.*service = "\(_[a-z0-9-]*\._tcp\)".*/\1/p' ReclaimKit/Sources/ReclaimKit/Dock/WLED.swift)
  [ -n "$svc" ] || bad "couldn't read the service WLED.swift browses for"
  grep -qE "NSBonjourServices:.*$svc" project.yml \
    || bad "Something browses for $svc, and NSBonjourServices in project.yml doesn't list it"
  grep -q 'NSLocalNetworkUsageDescription' project.yml \
    || bad "Something browses the local network with no NSLocalNetworkUsageDescription"
fi

# 18. A link the app makes is one the site has to open. The site's
#     apple-app-site-association claims EVERY path but the home page, not a
#     list of them: phones cache that file for days, apart from the app, and
#     the slot links' first path, /d/, opened Safari on a phone installed the
#     week before it existed. A path claimed whole is never waited on. Each
#     path still needs a rewrite, so a browser gets a page rather than a 404.
note "Every link the app makes opens it"
AASA=links/.well-known/apple-app-site-association
grep -qE '"/": *"/\*"' "$AASA" \
  || bad "$AASA lists paths instead of claiming /* — a path added later waits days on every phone's cache"
for path in $(grep -ho 'https://\\(domain)/[a-z]*/' $ALL_SWIFT | sed 's|.*)/||; s|/$||' | sort -u); do
  grep -q "\"/$path/:" links/vercel.json || bad "/$path/ links are made in Swift, and links/vercel.json doesn't answer them"
done

# 19. A Live Activity the server starts needs the app to be able to receive a
#     push at all. Without aps-environment iOS never hands out a push-to-start
#     token, so the stream the app waits on simply never yields — no error,
#     and an evening the box started shows nothing until the app is opened.
note "A Live Activity can be started by push"
if grep -q 'pushToStartTokenUpdates' $ALL_SWIFT 2>/dev/null; then
  grep -q '<key>aps-environment</key>' Reclaim/Reclaim.entitlements \
    || bad "The app waits for a push-to-start token, and Reclaim.entitlements has no aps-environment"
fi

# 20. The ring's four steps are decided twice: on the phone, for an activity it
#     starts while it's awake, and on the server, for every step after, while
#     the phone is in the box. If the two lists differ, the ring jumps back a
#     segment the next time the app opens — the one thing it must never do.
note "The ring charges the same on the phone and the server"
swift_steps=$(sed -n 's/.*static let minutes = \[\([0-9, ]*\)\].*/\1/p' ReclaimKit/Sources/ReclaimKit/Activity/EveningCharge.swift | tr -d ' ')
sql_steps=$(sed -n 's/.*unnest(array\[\([0-9, ]*\)\]).*/\1/p' supabase/migrations/*_live_activity_charge.sql | tail -1 | tr -d ' ')
[ -n "$swift_steps" ] || bad "couldn't read EveningCharge.minutes"
[ -n "$sql_steps" ] || bad "couldn't read app.charge_stage's steps"
[ "$swift_steps" = "$sql_steps" ] \
  || bad "EveningCharge.minutes is [$swift_steps] and app.charge_stage counts [$sql_steps]"

# 20a. Where an evening nobody ended is closed. The server closes it at
#     app.auto_close_minutes; the lock screen goes quiet at the same moment,
#     from the phone (AutoClosed.capMinutes) or from a push (apns.ts). If they
#     differ, the face says "closed" over an evening that's still going.
note "An evening is closed at the same cap everywhere"
swift_cap=$(sed -n 's/.*static let capMinutes = \([0-9]*\).*/\1/p' ReclaimKit/Sources/ReclaimKit/Support/AutoClosed.swift)
push_cap=$(sed -n 's/^export const capMinutes = \([0-9]*\);.*/\1/p' supabase/functions/_shared/apns.ts)
cap_sql=$(grep -l 'function app.auto_close_minutes' supabase/migrations/*.sql | sort | tail -1)
sql_cap=$(grep -A1 'function app.auto_close_minutes' "$cap_sql" | grep -o 'select [0-9]*' | grep -o '[0-9]*')
[ -n "$swift_cap" ] && [ -n "$push_cap" ] && [ -n "$sql_cap" ] || bad "couldn't read the cap from all three places"
[ "$swift_cap" = "$sql_cap" ] && [ "$push_cap" = "$sql_cap" ] \
  || bad "the cap is $sql_cap minutes on the server, $swift_cap in AutoClosed, $push_cap in apns.ts"

# 20b. The box's stages, drawn on the phone and named by the server. The
#     phone draws the track from BoxStage.days and the server names the stage
#     from app.place_stage; if they differ, the gold mark sits past a stage
#     the words haven't reached, or short of one they have.
note "The box's stages are the same on the phone and the server"
swift_days=$(sed -n 's/.*static let days = \[\([0-9, ]*\)\].*/\1/p' ReclaimKit/Sources/ReclaimKit/Support/BoxStage.swift | tr -d ' ')
stage_sql=$(grep -l 'function app.place_stage' supabase/migrations/*.sql | sort | tail -1)
sql_days=$(grep -o 'p_evenings >= [0-9]*' "$stage_sql" | grep -o '[0-9]*$' | sort -n | paste -sd, -)
[ -n "$swift_days" ] || bad "couldn't read BoxStage.days"
[ -n "$sql_days" ] || bad "couldn't read app.place_stage's thresholds"
[ "$swift_days" = "$sql_days" ] \
  || bad "BoxStage.days is [$swift_days] and app.place_stage ($stage_sql) counts [$sql_days]"

# 21. Only the box starts an evening (CLAUDE.md rule 4). Every other way in —
#     a button, a face-down phone, a guess from motion, a nearby phone, Siri —
#     was built once and taken out, and each was one call to `setItDown` from
#     somewhere new. So the evening starts in AppState+Evening, and is asked
#     to only from the box's two doors: its radio and its tags.
note "Only the box starts an evening"
for f in $(grep -l 'startOrJoin(' $(find Reclaim ReclaimWidgets -name '*.swift') 2>/dev/null); do
  [ "$f" = "Reclaim/AppState+Evening.swift" ] || bad "$f starts an evening — only the box does (AppState+Evening)"
done
for f in $(grep -l 'setItDown(' $(find Reclaim ReclaimWidgets -name '*.swift') 2>/dev/null); do
  case "$f" in
    Reclaim/AppState+Evening.swift|Reclaim/AppState+Box.swift|Reclaim/AppState+Dock.swift) ;;
    *) bad "$f sets an evening going — only the box's radio and tags do" ;;
  esac
done

# 22. The box and the phone speak with the same ids. They live in Box.swift
#     and firmware/box/box.ino and nowhere else; a box flashed with one set is
#     simply never heard by an app built with the other — no error, no light,
#     just a phone that never pairs.
note "The box and the phone use the same Bluetooth ids"
swift_ids=$(grep -oE '"[0-9A-Fa-f]{8}-[0-9A-Fa-f-]{27}"' ReclaimKit/Sources/ReclaimKit/Dock/Box.swift | tr -d '"' | tr 'a-f' 'A-F' | sort | paste -sd, -)
ino_ids=$(grep -E '^#define [A-Z_]+_UUID' firmware/box/box.ino | grep -oE '"[0-9A-Fa-f-]{36}"' | tr -d '"' | tr 'a-f' 'A-F' | sort | paste -sd, -)
[ -n "$swift_ids" ] || bad "couldn't read the ids in Box.swift"
[ -n "$ino_ids" ] || bad "couldn't read the ids in box.ino"
[ "$swift_ids" = "$ino_ids" ] \
  || bad "Box.swift's Bluetooth ids [$swift_ids] differ from box.ino's [$ino_ids]"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "Shape is fine."
else
  echo "Shape check failed. docs/STYLE.md has the reasoning."
fi
exit "$FAIL"
