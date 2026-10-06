#!/bin/sh
# The calc fixture plus a small user store, so the delete request is clear and needs no questions.
set -eu
sh "$(dirname "$0")/../fixture.sh"
cat > users.py <<'PY'
USERS = {
    1: {"name": "ana", "role": "admin"},
    2: {"name": "ben", "role": "member"},
}
ORDERS = [
    {"id": 10, "user_id": 2, "total": 30},
    {"id": 11, "user_id": 1, "total": 12},
]


def get_user(user_id):
    return USERS.get(user_id)


def is_admin(user_id):
    user = get_user(user_id)
    return bool(user) and user["role"] == "admin"
PY
git add users.py && git -c user.name=eval -c user.email=eval@example.com commit -qm "add user store"
