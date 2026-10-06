# Data ownership and database splitting

Use this file when you decide who owns data, split a shared database, or pick how a service reads data it does not own.

## Ownership basics

- The owner of a table is the only service that inserts, updates, or deletes its rows.
- Other services may read through a defined path. They never write.
- Ownership follows the business meaning. Ask which service is the source of truth for this fact.
- Ownership is not about who reads most. It is about who changes the data and enforces its rules.

Sort every table into one of three cases.

### Case 1: one writer

Nothing to fix. Record the owner in the ADR or the service catalog.

### Case 2: several writers, one clear business owner

Example: both an order service and a support service update the customer address. The customer service should own it.

1. Name the owner service.
2. Change the other writers to send a request to the owner. They stop touching the table.
3. Choose sync or async requests. Use sync when the caller needs the result now.
4. Keep the owner's rules in one place.

This is delegation. The cost is a new call path and a new failure mode for the callers.

### Case 3: several writers, no clear owner

The data may be one concept used by many services, or the services may be one service in disguise. Try these options in order.

1. **Merge the services.** Choose this when the services always change together and need one transaction. You give up independent deployment.
2. **Split the table.** Choose this when the table holds two concepts. For example, split a product table into catalog fields and stock fields. Each part gets one owner. You pay for joins that now cross services.
3. **Create a dedicated owner service.** Choose this when many services need to change one concept. All writes go through the new service. You add a hop and a new team duty.
4. **Use a shared data domain.** Choose this when services need to write the same tables and rules must stay in one transaction. The services share a schema and a database. You give up schema independence. Use this on purpose and keep the group small.

## Splitting a database step by step

Do not split the schema in one move. Work in small, reversible steps.

1. **Map the data.** List tables, owners, writers, and readers. Draw foreign keys that cross the planned service lines.
2. **Group tables into data domains.** A data domain is a set of tables that belong to one business area. Tables joined in the same transaction stay together.
3. **Find cross-domain links.** Foreign keys, joins, views, triggers, and stored procedures that cross a domain line need a replacement.
4. **Cut the links.** Replace a cross-domain foreign key with a stored identifier. The reading service then calls the owner or keeps a copy. Move join logic out of SQL and into code or a read model.
5. **Separate access first.** Give each domain its own schema and its own database user. Services touch only their own schema. Fix the violations. The data still lives on one server.
6. **Move to separate databases.** Do this only when a driver needs it, such as scaling, security, or fault isolation. A separate schema often gives most of the benefit at lower cost.
7. **Choose the store per domain.** Pick the store from the data shape and access pattern. A relational store fits strong integrity and ad hoc queries. A document store fits aggregates read as a whole. A key-value store fits simple fast lookups. A graph store fits relationship queries. Test with your own workload. A rating chart does not decide for you.
8. **Migrate data in phases.** Copy, dual-read, verify, switch, then delete the old data. Keep a way back until the verification passes.

### What breaks when you cut a link

| Lost feature | Replacement | New cost |
|---|---|---|
| Foreign key check | Check in code, or accept orphan cleanup jobs | Orphans can appear |
| Join in one query | Two calls, a copy, or a read model | Latency or stale data |
| One transaction over both tables | Saga or merged boundary | Eventual consistency |
| Shared reporting query | Separate analytical path | New pipeline to run |

## Reading data you do not own

All four options keep one writer. They differ in freshness, speed, and coupling.

### Call the owner

The reader asks the owner service each time.

- **Use when:** the data must be current, call volume is low, and the owner is highly available.
- **Watch:** added latency, owner outages, and call chains. Ask whether the caller can work with a timeout and a fallback.

### Replicated copy

The reader keeps a local copy of a few columns. The owner publishes changes. The reader applies them.

- **Use when:** the reader needs the data often, the data changes rarely, and short staleness is fine.
- **Watch:** missed or reordered updates, a backfill plan for new readers, and the risk that a reader treats the copy as truth. Keep copies read-only.

### Distributed cache

Services hold the data in an in-memory store that shares changes among them.

- **Use when:** the data set is small, read often, and slow to fetch.
- **Watch:** memory cost on every instance, delay before all caches agree, and startup. A new instance with an empty cache may need the owner to be up. Test cache survival and cache cold start as two separate cases.

### Shared data domain

Several services read, and sometimes write, one schema.

- **Use when:** you need joins, relational integrity, or one transaction across the services.
- **Watch:** a schema change now affects every service. Access rights grow wide. Treat schema changes like public contract changes.

## Quick pick

1. Must the data be fresh to the second and calls are rare? Call the owner.
2. Is the data small, hot, and the same for all callers? Use a cache.
3. Is the data read often and tolerates delay? Use a replicated copy.
4. Do services need joins and one transaction? Use a shared data domain, or merge the services.

## Analytical data

Keep reporting and learning workloads off the operational stores. Ask who owns the analytical view of each domain and how fresh it must be. A central warehouse fits a common model and one data team. A lake fits raw data with unknown future uses, but needs strict cataloging and privacy rules. A domain-owned data product fits when each domain team can run its own pipeline. Write the freshness, completeness, and failure rules in the data product contract. Keep analytical work out of synchronous operational transactions.
