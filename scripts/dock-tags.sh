#!/usr/bin/env bash
# The four links for a new box's slot tags, under one fresh secret.
#
#   scripts/dock-tags.sh
#
# Write each onto its slot's tag as a URL record — NFC Tools, free on the App
# Store, does it. One secret per box, never reused: it is the box's join
# credential, the same as a card's, and the first phone set into the box makes
# its place from it (`dock_place`, migration 0013).
#
# Never lock the tags. The domain is a testing address until there is a real
# one, and a locked tag can't be told where it moved.
set -euo pipefail
cd "$(dirname "$0")/.."

domain=$(sed -n 's/^[[:space:]]*LINK_DOMAIN:[[:space:]]*\([^[:space:]#]*\).*/\1/p' project.yml | head -1)
[ -n "$domain" ] || { echo "No LINK_DOMAIN in project.yml" >&2; exit 1; }

# 32 random bytes, URL-safe — the same shape as `Handle.newSecret()`.
secret=$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n')

for slot in 1 2 3 4; do
  echo "slot $slot  https://$domain/d/$secret/$slot"
done
