#!/usr/bin/env bash
# Copies the addon into the Forever AddOns folder. Re-run after edits. Remove with: install.sh remove
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
addons="${FOREVER_ADDONS:-/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns}"
dest="$addons/ForeverRealsReminder"

[ -d "$addons" ] || { echo "AddOns folder not found: $addons" >&2; exit 1; }
if [ -e "$dest" ] && [ ! -f "$dest/ForeverRealsReminder.toc" ]; then
    echo "Refusing: $dest exists and isn't an addon folder." >&2
    exit 1
fi
rm -rf "$dest"
if [ "${1:-}" = remove ]; then echo "Removed $dest"; exit 0; fi
mkdir -p "$dest"
# Every file the .toc lists, plus the .toc itself. Add Bindings.xml, Libs/ etc. here if you use them.
cp "$repo"/*.lua "$repo/ForeverRealsReminder.toc" "$dest/"
echo "Installed to $dest"
