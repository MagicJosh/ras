#!/bin/sh
# The calc fixture plus a CI workflow, which is a risky path.
set -eu
sh "$(dirname "$0")/../fixture.sh"
mkdir -p .github/workflows
cat > .github/workflows/ci.yml <<'YML'
name: ci
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.10"
      - run: python3 test_calc.py
YML
git add .github && git -c user.name=eval -c user.email=eval@example.com commit -qm "add ci"
