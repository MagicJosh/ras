#!/bin/sh
# Build the test repo for an eval case in the current directory.
# Usage: fixture.sh [flaky] [spec] [fix]
set -eu
cat > calc.py <<'PY'
def is_even(n):
    return n % 2 == 1
PY
cat > test_calc.py <<'PY'
from calc import is_even
assert is_even(4) is True
assert is_even(3) is False
print('ok')
PY
cat > app.py <<'PY'
from calc import is_even


def main(argv):
    for a in argv:
        print(a, is_even(int(a)))
PY
case " $* " in *" flaky "*)
cat > cart.py <<'PY'
def add_item(item, cart=[]):
    cart.append(item)
    return cart
PY
cat > test_cart.py <<'PY'
from cart import add_item


def test_one():
    assert add_item('a') == ['a']


def test_two():
    assert add_item('b') == ['b']


for t in (test_one, test_two):
    t()
print('ok')
PY
esac
git init -q
git add -A
git -c user.name=eval -c user.email=eval@example.com commit -qm init
case " $* " in *" spec "*)
mkdir -p specs
cat > specs/current.md <<'MD'
# Spec: Fix is_even

## Goal
is_even returns True for even numbers.

## Acceptance criteria
1. `python3 test_calc.py` prints ok.

## Non-goals
- No other changes.

## Blast radius
- calc.py line 2. Callers: app.py, test_calc.py.
MD
esac
case " $* " in *" fix "*)
cat > calc.py <<'PY'
def is_even(n):
    return n % 2 == 0
PY
esac
