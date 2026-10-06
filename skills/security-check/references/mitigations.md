# Safe-form mitigations

## SQL

Bind untrusted **values** using the driver placeholder syntax. Binding does not secure table names, column names, sort direction, or SQL fragments. Map user-selected identifiers through a fixed allowlist or the library's safe identifier-composition API.

## Shell

Pass an argument array with `shell=False`. Validate values for the domain. If a shell is unavoidable, keep untrusted data out of command syntax.

## Path containment

```python
from pathlib import Path
base_path = Path(base).resolve()
target = (base_path / user_name).resolve()
try:
    target.relative_to(base_path)
except ValueError as exc:
    raise ValueError("path escapes allowed root") from exc
```

Reject archive absolute paths, drive prefixes, and traversal before extraction.

## Secrets

Prefer managed/OS secret stores or injected environment variables. A local `.env` file is not universally forbidden, but must be excluded from version control, read only for an authorized need, and never echoed, copied to state, or sent externally. Reference exposed credentials by location, not value, and rotate them.

## Dependencies

Inspect source/reputation, exact version, lockfile diff, integrity metadata, install scripts, licenses when relevant, and network/runtime permissions.
