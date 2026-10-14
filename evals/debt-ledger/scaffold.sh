#!/bin/sh
# The calc fixture plus two marked shortcuts. The one in cache.js names no upgrade trigger.
set -eu
sh "$(dirname "$0")/../fixture.sh"
cat > report.py <<'PY'
def total(rows):
    # shortcut: loads every row into memory, upgrade when a file passes 100 MB
    return sum(r["amount"] for r in rows)
PY
cat > cache.js <<'JS'
// shortcut: no eviction
const cache = new Map();
module.exports = cache;
JS
git add report.py cache.js && git -c user.name=eval -c user.email=eval@example.com commit -qm "add report and cache"
