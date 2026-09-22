#!/usr/bin/env bash
# Put Reclaim on a phone with a free Apple ID.
#
#   scripts/free-team.sh                 # strip to what a personal team can sign
#   scripts/free-team.sh --team ABC123   # …and fill in the team, if you know it
#   scripts/free-team.sh --restore       # put the real capabilities back
#
# A free personal team cannot sign ANY of the four capabilities in
# Reclaim.entitlements: Sign in with Apple, Core NFC, Associated Domains and
# App Groups are all paid-membership entitlements, and Xcode refuses to build
# rather than dropping them quietly. So this removes all four, and renames the
# bundle, because `com.reclaim.app` may already be registered to someone else's
# account and the portal allows exactly one owner.
#
# Which sounds like it guts the app and doesn't, because of the second scheme.
# "Reclaim (Sample data)" is already signed in, in memory, and never
# constructs SupabaseRepository (see ReclaimApp.init) — so the four
# entitlements this removes are the four things that build never asks for.
# Rule 7 is the reason: nothing gates the ritual on a sensor, a permission or
# a network call, so with all of them gone there is still an evening to have.
#
# WHAT STOPS WORKING, and nothing here fails loudly, so read it once:
#   - Sign in with Apple. The real scheme cannot get past screen 1. Sample
#     data is the only scheme that runs.
#   - Reading and writing the tag by the door (screen 15), and the https tag
#     links that open the app when it's closed.
#   - The Control Centre toggle's accuracy. UserDefaults(suiteName:) returns
#     nil without the group, so SessionFlag reads false forever and writes go
#     nowhere. It degrades quietly by design — one tap fixes a wrong toggle.
#
# WHAT STILL WORKS: all 21 screens, the ceremony, the timer, face-down
# sensing (motion needs a usage string, not an entitlement) and the Live
# Activity (NSSupportsLiveActivities is an Info.plist key, not an entitlement).
#
# The install lasts seven days and then the app refuses to launch until you
# build it again. Nothing is lost when it expires — sample data was never on
# the device.

set -euo pipefail
cd "$(dirname "$0")/.."

BACKUP=.free-team-backup
FILES="Reclaim/Reclaim.entitlements ReclaimWidgets/ReclaimWidgets.entitlements project.yml"
stash() { printf '%s' "$1" | tr / _; }
die() { printf 'free-team: %s\n' "$1" >&2; exit 1; }

TEAM=""
PREFIX=""
case "${1:-}" in
  --restore)
    [ -d "$BACKUP" ] || die "nothing to restore — $BACKUP does not exist"
    for f in $FILES; do cp "$BACKUP/$(stash "$f")" "$f"; done
    rm -rf "$BACKUP"
    echo "Restored. Run 'xcodegen generate' to rebuild the project file."
    exit 0 ;;
  --help|-h)
    sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

while [ $# -gt 0 ]; do
  case "$1" in
    --team)   TEAM="${2:-}";   shift 2 || die "--team needs a value" ;;
    --prefix) PREFIX="${2:-}"; shift 2 || die "--prefix needs a value" ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -d "$BACKUP" ] && die "already applied — 'scripts/free-team.sh --restore' first"

# A bundle identifier is alphanumerics, hyphens and dots, so the login name
# gets everything else removed rather than escaped.
if [ -z "$PREFIX" ]; then
  who=$(id -un | tr '[:upper:]' '[:lower:]' | LC_ALL=C tr -cd 'a-z0-9')
  [ -n "$who" ] || who=local
  PREFIX="com.$who.reclaim"
fi

mkdir -p "$BACKUP"
for f in $FILES; do cp "$f" "$BACKUP/$(stash "$f")"; done

for f in Reclaim/Reclaim.entitlements ReclaimWidgets/ReclaimWidgets.entitlements; do
  cat > "$f" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<!-- Emptied by scripts/free-team.sh. A free personal team can sign none of
     what belongs here. 'scripts/free-team.sh --restore' puts it back, and
     scripts/shape.sh fails while this file is in this state, so it cannot be
     committed by accident. -->
<dict>
</dict>
</plist>
PLIST
done

tmp=$(mktemp)
sed -e "s|bundleIdPrefix: com\.reclaim|bundleIdPrefix: $PREFIX|" \
    -e "s|PRODUCT_BUNDLE_IDENTIFIER: com\.reclaim|PRODUCT_BUNDLE_IDENTIFIER: $PREFIX|" \
    project.yml > "$tmp"
[ -n "$TEAM" ] && sed -e "s|^\( *\)DEVELOPMENT_TEAM: .*|\1DEVELOPMENT_TEAM: \"$TEAM\"|" "$tmp" > "$tmp.2" \
  && mv "$tmp.2" "$tmp"
mv "$tmp" project.yml

# sed reports nothing when a pattern never matches, and a bundle identifier
# that silently stayed `com.reclaim.app` fails much later, inside Xcode.
grep -q "PRODUCT_BUNDLE_IDENTIFIER: $PREFIX.app$" project.yml \
  || die "the bundle identifier didn't change — project.yml has been restructured"
grep -q "PRODUCT_BUNDLE_IDENTIFIER: $PREFIX.app.widgets$" project.yml \
  || die "the widget bundle identifier didn't change — project.yml has been restructured"

# configFiles points both configurations at this file, so the project does not
# build without it. Sample data never reads either value.
if [ ! -f Config/Secrets.xcconfig ]; then
  cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
  echo "Wrote Config/Secrets.xcconfig from the example — sample data doesn't read it."
fi

cat <<EOF

Stripped to what a free Apple ID can sign.

  bundle       $PREFIX.app  (+ .widgets — two of your three app IDs)
  team         ${TEAM:-not set — pick your Apple ID in Signing & Capabilities}
  entitlements emptied, both targets

Next:

  xcodegen generate
  open Reclaim.xcodeproj

Choose the **Reclaim (Sample data)** scheme, not Reclaim — the plain scheme
needs Sign in with Apple and cannot get past screen 1 now. Plug the phone in,
pick it as the destination, Run. The first launch needs
Settings → General → VPN & Device Management → trust the certificate.

Seven days, then build it again. When you're done:

  scripts/free-team.sh --restore
EOF
