# Database function checklist

Use for stored functions, triggers, row-level security policies and grants. The examples are Postgres and Supabase. The questions apply to any database.

1. **Who can call it.** List the roles with execute rights. Revoke from roles that must not call it, for example `revoke execute on function f(...) from public, anon;`. A new function can get execute rights by default.
2. **Identity checks fail closed.** `if user_id != auth.uid()` does nothing when no user is signed in, because a comparison with null is null. Write `if auth.uid() is null or user_id is distinct from auth.uid()`.
3. **Elevated rights.** A function that runs with its owner's rights (`security definer`) needs a fixed `search_path`, for example `set search_path = ''`, and schema-qualified names.
4. **Check then act.** A guard that counts or reads rows and then writes, for example "keep at least one admin", fails when two callers pass the check at once. Lock the rows the check reads (`select ... for update` on the whole set), or move the rule into a constraint.
5. **Replaced functions.** Drop the old function when a new one replaces it. A privileged function that nothing calls is still callable.
6. **Test as the caller.** On a local copy, switch to the caller's role and claims, then call the function. For check-then-act, use two sessions and hold the first one open between the check and the write. Never test on production.
