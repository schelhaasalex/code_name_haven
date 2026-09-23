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
#    The interruption screens are the ones that matter: 13, 14, 18 and 20 are
#    unreachable at runtime without an auto-close, a broken rhythm, a still
#    phone or five evenings.
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

# 10. App Shortcuts are only read from the app target. Declared in ReclaimKit,
#     the intents were registered but the Siri phrases never were — the build
#     succeeded and `autoShortcuts` in the app's metadata came out empty.
note "Siri phrases live in the app target"
elsewhere=$(grep -l 'AppShortcutsProvider' $(find ReclaimKit/Sources ReclaimWidgets -name '*.swift') 2>/dev/null)
for f in $elsewhere; do
  bad "$f declares an AppShortcutsProvider — only one in Reclaim/ is ever read"
done
[ "$(grep -l ': AppShortcutsProvider' $(find Reclaim -name '*.swift') 2>/dev/null | wc -l | tr -d ' ')" = "1" ] \
  || bad "Reclaim/ should declare exactly one AppShortcutsProvider"

# 11. The App Group is one name written three times: two entitlements files and
#     SessionFlag. If they disagree, the Control Centre toggle reads a store
#     nothing writes to, and shows "off" forever — no error anywhere.
note "The App Group is the same everywhere"
groups=$( { grep -ho 'group\.[A-Za-z0-9.-]*' Reclaim/Reclaim.entitlements ReclaimWidgets/ReclaimWidgets.entitlements
            grep -ho '"group\.[A-Za-z0-9.-]*"' ReclaimKit/Sources/ReclaimKit/Activity/SessionFlag.swift | tr -d '"'; } | sort -u)
[ "$(printf '%s\n' "$groups" | grep -c .)" = "1" ] \
  || bad "App Group differs between the entitlements and SessionFlag: $(echo $groups)"

# 12. One domain, set once. Links are printed onto cards and sent in messages,
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

# 14. The phone that is DOWN is the one that has to keep talking, and it does
#     that with the screen off. Without `bluetooth-peripheral` in
#     UIBackgroundModes iOS stops the advertisement the moment the app leaves
#     the foreground — which is one second after the person sets the phone
#     down, and is the entire feature. Nothing errors; the other phones simply
#     never hear it. The usage string is the other half: its absence is not a
#     silent failure but a crash on first use.
note "A phone that is down keeps talking"
if grep -lq 'CBPeripheralManager' $ALL_SWIFT 2>/dev/null; then
  grep -q 'bluetooth-peripheral' project.yml \
    || bad "Something advertises over Bluetooth, but UIBackgroundModes has no bluetooth-peripheral"
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

echo
if [ "$FAIL" -eq 0 ]; then
  echo "Shape is fine."
else
  echo "Shape check failed. docs/STYLE.md has the reasoning."
fi
exit "$FAIL"
