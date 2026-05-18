# BurgerQuick Systems — A Technical History (2000–2023)

## Prologue

This repository is the production codebase for BurgerQuick, a regional fast-food chain founded in 1999 and grown to 200+ locations across 14 states. The code tells the story of 23 years of organic IT growth: every architectural decision, every compromise, every "temporary" fix that became permanent, every developer who left their mark.

Nothing here was planned to be messy. It became messy the way all long-lived systems do — one urgent deadline at a time.

---

## Act I: The Beginning (2000)

### The Founding

BurgerQuick opened its first store in 1999. In January 2000, they hired **Mike Henderson** as their first — and only — IT person. Mike was a DBA who had been working with Oracle since version 6. He believed in three things:

1. **The database is the application.** All business logic lives in PL/SQL. The frontend is just for display.
2. **Natural keys are better than surrogate keys.** You can read them. They mean something.
3. **One package to rule them all.** If you need something, put it in the existing package. Don't create new ones.

### What Mike Built

Mike created two tables (`EMPLOYEES`, `INVENTORY_ITEMS`) and one package (`PKG_STORE_OPS`) that handled everything: hiring, firing, inventory adjustments, audit logging. He chose Oracle ADF for the UI because Oracle sent a salesperson to the office and Mike liked the demo.

The original code was clean, consistent, and well-structured for a single-developer project. Mike used:
- `employee_id VARCHAR2(10)` with format `BQ-EMP-0001` — human-readable keys
- `CHAR(1)` for boolean flags (`Y`/`N`)
- `DATE` columns suffixed `_date`
- `VARCHAR2(4000)` for audit log values — "nobody will ever write more than 4000 characters in an audit note"
- SSNs stored as plain text — "it's in the database, the database has access control, what's the problem?"

The employee directory page (`employeeDirectory.jspx`) was built by dragging an ADF table component onto a page in JDeveloper. It was supposed to be a prototype. It's still in production.

### Mike's Principles, Captured in Code

```
-- All business logic goes in the database. Apps are just for display.
-- - Mike, PKG_STORE_OPS header comment, March 2000
```

This principle shaped the entire architecture. Twenty years later, the database contains over 40 stored procedures and packages, some 1,000+ lines long, maintained by people who have never met Mike.

---

## Act II: Growth Pains (2003)

### Sarah Arrives

By 2003, BurgerQuick had 8 stores and 120 employees. Mike couldn't handle all the IT work alone. They hired **Sarah Mitchell**, a Java developer with 5 years of experience, as the second technical hire.

Sarah had different preferences:
- **Surrogate keys** (`NUMBER` IDs with sequences) instead of formatted string keys
- **Standalone procedures** with `sp_` prefix instead of one monolithic package
- **Separate concerns** — orders go in one place, employees in another
- **`_yn` suffix** for boolean columns instead of `is_` prefix
- **`_dt` suffix** for dates instead of `_date`

These differences seem minor. Multiplied by 20 years of code, they became a field guide to who wrote what.

### What Sarah Built

Sarah created the `STORES`, `MENU_ITEMS`, `ORDERS`, and `ORDER_ITEMS` tables — the core of the business. She wrote `sp_OrderProcessing` as a collection of standalone procedures with the `sp_` prefix.

She called Mike's `PKG_STORE_OPS` for inventory updates because "no need to rewrite what already works." This established a pattern that would define the next two decades: **new code calling old code, creating chains of dependencies that nobody fully mapped.**

### The First Duplication

Sarah needed to calculate inventory usage for reporting. `sp_complete_order` already had inventory deduction logic, but the regional manager wanted a separate report that didn't affect inventory. Sarah could have added a parameter to `sp_complete_order` to make it read-only. But `sp_complete_order` was already in production, and Mike's policy was "don't touch running code."

So she wrote `sp_calculate_inventory_usage` — a copy of the inventory deduction logic that returned data instead of updating. She added a comment:

```
-- If you change the SKU mapping in sp_complete_order, CHANGE IT HERE TOO!
```

Nobody would remember to do this. Over the next 20 years, the SKU mapping would diverge in subtle ways, causing inventory discrepancies that accounting would manually reconcile each month.

### The Date Helper Schism

Sarah couldn't find Mike's date utilities (they were in a package called `model.util` that wasn't documented). She wrote her own: `DateHelper.java`. Her `daysBetween()` rounds UP for partial days. Mike's `LegacyDateUtils.daysBetween()` rounds DOWN. Both are used in production. The rounding difference caused a franchise royalty dispute in 2011 that settled for $8,000.

---

## Act III: Offshore Expansion (2006)

### The Franchise Team

In 2006, BurgerQuick began franchising. They hired an offshore development team of three: **Raj** (lead), **Priya**, and **Anil**. The team was given a 4-month contract to build the franchise management module.

They received a requirements document from corporate, access to the codebase, and instructions to "follow existing patterns." The problem: the existing patterns were Mike's and Sarah's — two completely different styles.

### The Third Convention

The offshore team created their own conventions, different from both Mike and Sarah:

| Element | Mike (2000) | Sarah (2003) | Offshore (2006) |
|---------|-------------|--------------|-----------------|
| Boolean flag | `is_active CHAR(1)` | `approved_yn CHAR(1)` | `status VARCHAR2(20)` |
| Date column | `created_date` | `created_dt` | `create_date` |
| "By" column | `created_by` | — | `create_user` |
| PK naming | Natural key as PK | `{table}_id NUMBER` | `{table}_id NUMBER` |
| Phone column | `phone` | — | `phone_primary`, `phone_secondary` |
| State column | `state VARCHAR2(2)` | — | `state_cd VARCHAR2(2)` |
| Procedure style | Package | `sp_` prefix (standalone) | Package (different structure) |

Within the same `FRANCHISES` and `FRANCHISE_OWNERS` tables, column naming isn't even self-consistent — `owner_first_nm` in one table, `first_nm` in another.

### The Unfinished Junction Table

The offshore team created `FRANCHISE_OWNER_LINK` as a junction table between franchises and owners. They never finished populating it. Owner data is duplicated between `FRANCHISES` and `FRANCHISE_OWNERS` instead. The junction table sits empty in production, waiting for a data migration that was scheduled for "Q2 2007" and never happened.

### The Supplier Inventory Problem

Anil's `SUPPLIER_PKG` needed to receive inventory and update stock levels. He could have called `PKG_STORE_OPS.update_inventory` — but that procedure didn't track which supplier delivered the goods. He could have modified Mike's procedure — but the offshore team wasn't sure if they were "allowed" to modify the original developer's code.

So he wrote `receive_inventory_from_supplier` — a new procedure that does the same inventory update as Mike's, plus supplier tracking. The comment explains:

```
-- Should've just extended Mike's original proc but we weren't
-- sure if he'd be OK with us modifying his code.
```

This pattern — **duplicating instead of extending, because the original author might object or the original code might break** — became a cultural norm at BurgerQuick.

---

## Act IV: The Web Arrives (2009)

### Jason's World

By 2009, BurgerQuick had 45 stores and needed an online ordering website. They hired **Jason Miller**, a web developer whose expertise was HTML/CSS/JavaScript with some Java. He had never written PL/SQL before joining BurgerQuick.

Jason built the customer-facing website: customer registration, online ordering, store locator. He created the `CUSTOMERS` and `ONLINE_ORDERS` tables.

### Why Another Orders Table?

Sarah's `ORDERS` table already existed for in-store orders. Jason could have added an `order_source` column. But:

1. Web orders have different statuses (`RECEIVED → CONFIRMED → PREPARING → READY → PICKED_UP` vs in-store's `NEW → COMPLETED`)
2. Web orders have different payment fields (Stripe tokens, not "CASH/CREDIT/CHECK")
3. Web orders have customers, not just anonymous cash transactions
4. Jason "didn't want to break the POS system" by modifying Sarah's table

So he created `ONLINE_ORDERS` and `ONLINE_ORDER_ITEMS` — a parallel order system that mirrors the existing one. Now there are two ways to represent an order, two sets of status values, two ways to calculate totals, and two inventory deduction paths.

### The Deep Nesting Begins

Jason's `WEB_ORDER_PKG.place_online_order` needed to:
1. Create the web order record
2. Push it to the store's POS system (so the kitchen sees it)
3. Deduct inventory

For step 2, he called Sarah's `sp_create_order`. For step 3, he called Sarah's `sp_complete_order`, which internally called Mike's `PKG_STORE_OPS.update_inventory`.

For the first time, a procedure call chain went 3 levels deep:
```
WEB_ORDER_PKG.place_online_order (Jason, 2009)
  → sp_create_order (Sarah, 2003)
  → sp_complete_order (Sarah, 2003)
    → PKG_STORE_OPS.update_inventory (Mike, 2000)
```

Jason documented this in a comment:
```
-- This creates a nested call chain:
-- WEB_ORDER_PKG.place_online_order
--   -> sp_complete_order
--     -> PKG_STORE_OPS.update_inventory
-- Be careful modifying any of these.
```

Nobody would read that comment before modifying `PKG_STORE_OPS.update_inventory` in 2023.

### The Pseudo-JSON Parsing

Jason needed to pass order items from the website to the database. JSON libraries weren't available in Oracle 10g (the database version at the time). So he invented a "JSON-like" format: `"[{menu_id:1,qty:2},{menu_id:3,qty:1}]"` and wrote a PL/SQL parser for it.

The parser was a stub. It returned 0. The actual parsing happened in Java. The comment says:

```
-- REAL IMPLEMENTATION: This is a stub. The actual parsing happens
-- in Java before calling this proc. See OrderBean.java.
```

In 2012, the mobile team used actual JSON (via a newer Oracle version). But Jason's pseudo-JSON format was never removed. Both formats are still accepted. `WEB_ORDER_PKG` handles the old format. `p_MobileOps` handles the new one. Neither team knew the other's code existed.

---

## Act V: Mobile & Loyalty (2012)

### The Agency Contractors

In 2012, BurgerQuick launched a loyalty program and a mobile app. They hired **TechBridge Solutions**, a development agency, on a 6-month contract. The team was **Dmitri** (lead), **Alex**, and **Wei**.

The agency had never worked with Oracle ADF before. They were Java/Spring developers who learned PL/SQL on the job.

### The Fourth Naming Convention

Wei wrote `p_MobileOps` — a package with camelCase procedure names because "that's how we write code":

```sql
PROCEDURE authenticateUser(...)
PROCEDURE getNearbyStores(...)
PROCEDURE placeMobileOrder(...)
```

This is completely different from `PKG_STORE_OPS` (UPPER_SNAKE_CASE), `sp_create_order` (snake_case with prefix), and `FRANCHISE_PKG` (UPPER_SNAKE_CASE with suffix). Four naming conventions now coexist in the same database.

### The Loyalty System

The loyalty system (`LOYALTY_PKG`) introduced `LOYALTY_POINTS`, `REWARDS`, and `CUSTOMER_REWARDS` tables. It needed to deduct inventory when customers redeemed rewards for free items.

The agency team called `sp_complete_order` for the inventory deduction — the same procedure Jason's web orders used, which was the same procedure the POS system used. But their reward items included things the hardcoded SKU mapping in `sp_complete_order` didn't cover (drinks, desserts — menu items 4+).

Dmitri added `LOYALTY_PKG.inventory_for_reward()` as a workaround. It contains a THIRD copy of the menu-to-SKU mapping:

```
-- First copy: sp_complete_order (2003)
-- Second copy: sp_calculate_inventory_usage (2003)
-- Third copy: here
-- If a new menu item is added, all three must be updated.
```

None of them were kept in sync.

### The 45-Minute Nightly Recalc

The loyalty points system had a design flaw: cancelled orders and refunds would leave points in customers' accounts. The fix was `LOYALTY_PKG.nightly_points_recalc` — a procedure that recalculates every customer's points from scratch every night.

It uses a **triple-nested cursor loop**: customers → orders → online orders. With 50,000 customers averaging 100 orders, that's 5 million iterations. It takes 45 minutes. If it fails (which happens when someone clicks the "Refresh Loyalty" button during business hours), the entire order system blocks because the procedure holds row-level locks.

The comment acknowledges this:

```
-- Yes, we know this is bad. The alternative was a complex analytic
-- query that the team wasn't confident writing in Oracle SQL.
-- The agency contract ended before we could optimize it.
```

The contract ended in June 2012. The procedure has run every night since, unchanging.

### The Forgotten Customer Lookup

The mobile app needed to look up customers. Wei wrote `p_MobileOps.authenticateUser()` which queries the `CUSTOMERS` table directly. The web team already had `sp_get_customer_by_email()` which did the same thing. Neither team knew about the other's implementation.

A 2013 comment in `customer_mgmt.sql` explains:

```
-- The loyalty team created their own customer lookup in LOYALTY_PKG.
-- They didn't know sp_get_customer_by_email existed.
-- So now there are two completely different ways to look up a customer.
-- This one returns a cursor. Theirs returns a custom type.
-- The web app uses this one. The mobile app uses theirs.
-- Don't merge them, both are in production with different consumers.
```

---

## Act VI: The Analytics Era (2015)

### The BI Consultants

In 2015, BurgerQuick hired **DataCorp BI Consultants** to build a reporting system. The consultants specialized in Oracle BI but not in BurgerQuick's specific database schema (which nobody fully understood by this point).

### The Package Name

The consultants went through several iterations of their reporting package:
- `RPT_DAILY_SALES` (intern, 2013) — scrapped
- `RPT_DAILY_SALES_V2` (never finished)
- `RPT_DAILY_SALES_V2_FINAL` (had bugs)
- `RPT_DAILY_SALES_V2_FINAL_USE_THIS` — the current version

The name is absurd. It's referenced in BI dashboards, Excel macros, and the CFO's monthly report generator. Renaming it would break all of those. So BurgerQuick's core sales reporting package is permanently named `RPT_DAILY_SALES_V2_FINAL_USE_THIS`.

### The Temp Table Strategy


The BI team found that querying `ORDERS` directly was too slow — the table had grown to millions of rows and lacked proper indexes on the date columns. Instead of adding indexes (which would slow down inserts during peak hours), they created global temporary tables (`TEMP_REPORT_BUILDER`, `TEMP_CUSTOMER_SEGMENTS`) that get refreshed nightly.

The refresh logic was stored in a DBMS_SCHEDULER job on the production server. When the DBA server crashed in 2017, the original refresh SQL was lost. The job still runs from the saved scheduler configuration, but the source code is gone. The procedure body in this repository is a placeholder:

```sql
NULL;  -- See DBMS_SCHEDULER for actual implementation
```

If that scheduler job ever fails and needs to be recreated, nobody knows the exact SQL it runs.

### The Materialized View Nobody Knows About

Somewhere in the production database, there's a materialized view called `MV_LEGACY_DAILY_SALES_PRE_2015`. It was created in 2012 by an unknown developer. It's not in this codebase. It's still being refreshed by a cron job nobody has located. The CFO's Excel spreadsheet connects directly to it via ODBC. Dropping it would break the monthly financial reports.

The comment in `materialized_views.sql` warns:

```
-- Dropping it might break the CFO's Excel spreadsheet that
-- connects directly to it via ODBC. Leave it alone.
```

Nobody knows what columns it has, what data it aggregates, or whether it still produces correct results. The monthly numbers are cross-checked against a different report and manually adjusted. This has been the process since 2015.

---

## Act VII: The Modernization That Wasn't (2018)

### The New CTO

In January 2018, BurgerQuick hired **Kevin Park** as their new CTO. Kevin came from a startup background. He looked at the BurgerQuick codebase and saw a monolith that needed to be "modernized": REST APIs, microservices, cloud migration.

He hired **Marcus Chen** as a senior developer to lead the modernization effort.

### Phase 1: REST Wrappers

Marcus created `API_ORDER_SERVICE` — a PL/SQL package that wraps the existing stored procedures with REST-friendly interfaces. The idea was:

```
Mobile App → REST API → API_ORDER_SERVICE → Legacy stored procedures
```

The wrappers worked. But they added another layer to already-deep call chains:

```
API_ORDER_SERVICE.api_create_order (Marcus, 2018)
  → WEB_ORDER_PKG.place_online_order (Jason, 2009)
    → sp_create_order (Sarah, 2003)
    → sp_complete_order (Sarah, 2003)
      → PKG_STORE_OPS.update_inventory (Mike, 2000)
```

That's 5 levels. For creating an order. The CTO's vision was that Phase 2 would collapse this chain by replacing the legacy procedures with microservices. Phase 2 never happened.

### The Abandoned User Service

Marcus designed a `USERS` table — a clean, normalized user entity that would replace `EMPLOYEES`, `CUSTOMERS`, and `FRANCHISE_OWNERS`. It used:
- UUIDs as primary keys (nothing else in the database uses UUIDs)
- bcrypt password hashing (everything else uses SHA-256)
- Soft deletes with `deleted_at` timestamps (everything else uses `is_active` flags)
- Proper constraints and check constraints

It was beautifully designed. Completely incompatible with every other table in the database.

The migration script was never written. The password re-hashing (SHA-256 → bcrypt) would require all users to reset their passwords, and the PM said "absolutely not." Kevin's budget was reallocated in August 2018. He left the company.

Marcus stayed but was reassigned to "more critical work." The `USERS` table sits empty in production — a ghost of a future that never arrived.

### The Half-Implemented REST Controller

Marcus's `OrderRestController.java` has a `createOrder` endpoint. It's wired to accept JSON. But the backend connection was never completed because the JAX-RS library wasn't properly configured in WebLogic. The endpoint returns:

```json
{
  "status": "PLACEHOLDER",
  "message": "REST endpoint not yet connected to backend. Use the JSF UI or mobile app for order creation.",
  "note": "This was a CTO initiative. The CTO left. Contact engineering manager for status."
}
```

This has been the response since July 2018. The mobile app (Android) calls the REST endpoint, gets the placeholder, and falls back to calling the stored procedures directly. Nobody has removed the REST endpoint because "Phase 2 might still happen."

---

## Act VIII: The Pandemic Pivot (2020)

### Emergency Delivery

In March 2020, COVID-19 hit. BurgerQuick's dining rooms closed. The company needed delivery capability immediately — not in 3 months with proper planning, but this week.

An emergency SWAT team was assembled from available contractors and whoever wasn't furloughed. **Dave**, a contractor who had been working on an unrelated project, became the de facto delivery module developer.

### Built in 3 Days

The delivery module (`DELIVERY_PKG`, `DELIVERY_ORDERS`, `DELIVERY_DRIVERS`, `deliveryTracker.jspx`, `DeliveryTrackerBean.java`) was built in 3 days. The approach: copy the existing order management code and modify it for delivery.

Dave copied:
- `sp_OrderProcessing` → `DELIVERY_PKG` (PL/SQL)
- `onlineOrder.jspx` → `deliveryTracker.jspx` (JSF page)
- `LoyaltyBean.java` → `DeliveryTrackerBean.java` (managed bean)

Each file still contains remnants of its origin. `DeliveryTrackerBean` has `loyaltyPointsBalance` and `loyaltyTier` fields because the copy-paste included them and removing them causes JSF EL expression errors. They always return 0.

`deliveryTracker.jspx` has a hidden `<div>` containing loyalty elements because the page template references their IDs. The global error handler is configured to suppress "Target not found" errors because fixing 47 pages worth of copy-paste artifacts was deemed too expensive.

### The Double-Assign Bug

`DELIVERY_PKG.assign_driver` doesn't check if a driver is already assigned to another delivery. A driver can be assigned to multiple simultaneous deliveries. This was noted as "will fix in next sprint" in March 2020. The sprint never happened. The contract ended.

Drivers now know to check their app for double assignments and call the dispatcher if it happens. The dispatcher manually reassigns deliveries in the database. This workaround has been operational for 3 years and is now "the process."

### The Inventory Deduction That Wasn't

Dave wrote `DELIVERY_PKG.deduct_inventory_for_delivery` — a procedure that does nothing. The comment explains:

```
-- Inventory was already deducted when the web order was placed
-- (see WEB_ORDER_PKG.place_online_order which calls sp_complete_order).
-- So this is redundant for items, but NOT redundant for new delivery-specific
-- items like delivery bags, stickers, etc.
--
-- TODO: Add inventory items for delivery supplies - Dave, March 2020
-- TODO: Still waiting on the SKU numbers for delivery supplies - Dave, April 2020
-- Dave's contract ended. Someone else needs to follow up.
--
-- For now, NO-OP.
```

Delivery supplies (bags, stickers, tamper seals) have never been tracked in inventory. The cost is absorbed as "miscellaneous expense." Accounting has been asking about this since Q3 2020.

---

## Act IX: The Present (2023)

### Where Things Stand

BurgerQuick now has 200+ stores, 12,000 employees, and an IT department of 25. The codebase contains:

| Artifact | Count |
|----------|-------|
| Database tables | 20+ (plus 3 abandoned) |
| Stored procedures/packages | 15 packages, 40+ procedures |
| Java classes | 30+ |
| JSF pages | 15+ |
| Naming conventions | 4 (Mike, Sarah, offshore, agency) |
| Duplicate implementations of "calculate order total" | 4 |
| Duplicate implementations of "look up customer" | 3 |
| Duplicate implementations of "menu-to-SKU mapping" | 3 |
| Half-finished features | 5+ |
| Dead tables in production | 3 known, possibly more |

### The Known Issues

The file `Model/database/2023_current/01_known_issues.sql` catalogs the technical debt. Highlights:

- **Everything flows into `PKG_STORE_OPS.update_inventory`.** If that procedure breaks, every sales channel (POS, web, mobile, delivery, loyalty redemptions) stops working simultaneously.
- **The menu-to-SKU mapping is hardcoded in 3 places.** Adding a new menu item requires updating all three. Nobody does this consistently.
- **`cancel_online_order` restocks inventory as `BEEF-PATTY-4`** regardless of what was actually ordered. This bug is from 2009.
- **The nightly loyalty recalc** takes 45 minutes and blocks other processes. If it fails, all customer points are wrong.
- **Naming conventions are inconsistent** across the entire database. `is_active`, `_yn`, `_flg`, and `is_active_flg` all mean the same thing.
- **The `USERS` table** (2018 modernization) exists but is empty. New developers sometimes mistake it for the canonical user table.

### The Original Developer

Mike Henderson is still at BurgerQuick. He's the only person who fully understands `PKG_STORE_OPS`. He's 58. He has mentioned retirement.

When asked about the state of the codebase at a 2022 all-hands, Mike said:

> "I built a system for one store and 15 employees. It grew. That's what systems do. The fact that it still runs, 23 years later, processing 10,000 orders a day across 200 stores — that's not a failure of architecture. That's a success of engineering."

Nobody was sure if he was joking.

### What's Next

There have been proposals:
- **"Project Clean Slate"** (2021): Rewrite everything as cloud-native microservices. Estimated 2 years, $4M. Rejected by the board.
- **"Strangler Fig"** (2022): Gradually replace legacy procedures with modern services. Started with a pilot. The pilot is still running. Nothing has been replaced yet.
- **"Just Document It"** (2023): Accept the current state and document everything. This repository is part of that effort.

---

## Field Guide: How to Read This Codebase

### Naming Convention Map

| If you see... | It was probably written by... | In... |
|---------------|------------------------------|-------|
| UPPER_SNAKE_CASE packages | Mike | 2000 |
| `sp_` prefixed standalone procs | Sarah | 2003 |
| Column suffix `_yn` | Sarah | 2003 |
| Column suffix `_dt` | Sarah | 2003 |
| Column suffix `_date` | Mike | 2000 |
| Column suffix `_cd` | Offshore team | 2006 |
| Abbreviated column names (`_nm`) | Offshore team | 2006 |
| camelCase procedure names | Wei (agency) | 2012 |
| Column suffix `_flg` | Agency team | 2012 |
| `is_active_flg` (combined convention) | Delivery SWAT | 2020 |
| `VARCHAR2(36)` UUID primary key | Marcus (CTO's team) | 2018 |
| `_yn CHAR(1)` | Sarah | 2003 |
| `is_active CHAR(1)` | Mike | 2000 |

### Call Chain Depth

When debugging, trace the call from the entry point down to `PKG_STORE_OPS`. Everything eventually reaches Mike's code. The deepest chain is 5 levels (API → Web → Order → Completion → Inventory). If you haven't reached Mike's code, you haven't found the root cause.

### "Don't Touch" List

These things exist in production but should not be modified without extensive testing:
- `PKG_STORE_OPS.update_inventory` — called by everything
- `sp_complete_order` — called by 6+ other procedures
- `ORDERS` table structure — POS integration depends on exact column ordering
- `MV_LEGACY_DAILY_SALES_PRE_2015` — CFO's Excel depends on it
- The DBMS_SCHEDULER nightly refresh job — source code lost, only exists in production
- `exportFranchiseDataLegacy()` method — deleting it breaks the build for unknown reasons
- `RPT_DAILY_SALES_V2_FINAL_USE_THIS` package — name is ridiculous but changing it breaks BI dashboards

### The Golden Rule

> Before modifying any stored procedure, check who calls it. Then check who calls those callers. Then check who calls THOSE callers. If you get to Mike's original code, involve Mike.
>
> — BurgerQuick Engineering Wiki (last updated: 2018)

---

*This document was compiled from code comments, git history, Confluence pages, JIRA tickets, incident reports, and interviews with current and former BurgerQuick IT staff. Some details have been dramatized for narrative coherence. The technical debt is real.*
