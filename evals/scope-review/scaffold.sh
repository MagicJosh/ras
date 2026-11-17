#!/bin/sh
# The spec fixes is_even in calc.py and says "No other changes". The working tree holds that fix,
# and also a new --quiet option in app.py that nobody asked for. Nothing is committed.
set -eu
sh "$(dirname "$0")/../fixture.sh" spec fix
cat > app.py <<'PY'
from calc import is_even


def main(argv):
    quiet = '--quiet' in argv
    for a in argv:
        if a == '--quiet':
            continue
        if quiet:
            print(is_even(int(a)))
        else:
            print(a, is_even(int(a)))
PY
