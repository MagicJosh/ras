#!/bin/sh
# The calc fixture plus a project .gitignore with one known line.
set -eu
sh "$(dirname "$0")/../fixture.sh"
printf '__pycache__/\n' > .gitignore
git add .gitignore && git -c user.name=eval -c user.email=eval@example.com commit -qm "add gitignore"
