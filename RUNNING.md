# How to Run BurgerQuick Systems

This is an Oracle ADF application. It needs the Oracle stack — there's no `npm install && npm start` equivalent. Here's what you can do, from easiest to most complete.

---

## Quickest: Just Read the Code

The PoC is designed to be read. Start here:

```
1. LEGACY_HISTORY.md         ← The full 23-year story
2. Model/database/           ← Trace the evolution era by era
3. Model/src/model/          ← Java business layer with era-specific comments
4. ViewController/           ← UI pages and managed beans
```

Every file has extensive comments telling you when it was written, by whom, why it's messy, and how it connects to everything else.

---

## Run the Database Layer (PL/SQL)

### Step 1: Get Oracle Database

**Option A — Oracle XE (free, local)**
- Download [Oracle Database XE 21c](https://www.oracle.com/database/technologies/xe-downloads.html)
- Install (it's a standard Linux RPM or Windows installer)
- Creates a database called `XEPDB1` with a pluggable database

**Option B — Docker (easiest)**
```bash
docker run -d --name oracle-xe \
  -p 1521:1521 -p 5500:5500 \
  -e ORACLE_PASSWORD=burgerquick \
  container-registry.oracle.com/database/express:21.3.0-xe
```

**Option C — Oracle Autonomous Database (cloud, free tier)**
- Sign up at oracle.com/cloud/free
- Create an "Always Free" Autonomous Database
- Use SQL Developer Web (browser-based) to run scripts

### Step 2: Run the SQL scripts

Connect to your database, then:

```bash
# Using SQL*Plus (command-line tool that comes with Oracle):
sqlplus system/yourpassword@localhost:1521/XEPDB1

# Then at the SQL> prompt:
SQL> @install_all.sql
```

Or use **Oracle SQL Developer** (free GUI tool — much friendlier):
1. Download [SQL Developer](https://www.oracle.com/database/sqldeveloper/)
2. Connect to your database
3. Open `install_all.sql`
4. Run it (F5)

### What you'll have

After running the script, you'll have:
- 20+ tables with seed data
- 9 PL/SQL packages with 40+ stored procedures
- You can call procedures like:
  ```sql
  -- Hire someone (Mike's original interface, 2000)
  EXEC PKG_STORE_OPS.hire_employee('John', 'Doe', '111-22-3333', '1', 'Cook', 10.50);

  -- Place an online order (Jason's web interface, 2009)
  DECLARE
    v_order_id NUMBER;
  BEGIN
    WEB_ORDER_PKG.place_online_order(1000, 1, SYSDATE+1/24,
      '[{menu_id:1,qty:2}]', 'CREDIT', '4242', v_order_id);
  END;
  /

  -- See the deep call chain in action:
  -- API_ORDER_SERVICE → WEB_ORDER_PKG → sp_complete_order → PKG_STORE_OPS.update_inventory
  ```

---

## Run the Full ADF Application

This is the heavy option. You need JDeveloper.

### Step 1: Install JDeveloper 12c

1. Download [JDeveloper 12.2.1.4](https://www.oracle.com/tools/downloads/jdeveloper-12214-downloads.html)
2. It's ~2 GB. Install it.
3. It comes with an integrated WebLogic Server

### Step 2: Open the project

1. Launch JDeveloper
2. File → Open → navigate to `Application1.jws`
3. JDeveloper will recognize the workspace with its two projects (Model, ViewController)

### Step 3: Configure database connection

1. In JDeveloper, go to Window → Databases
2. Right-click → New Connection
3. Enter your Oracle XE connection details
4. The connection is referenced in `.adf/META-INF/adf-config.xml`

### Step 4: Run

1. Right-click `ViewController` project → Run
2. This starts the integrated WebLogic server
3. Opens a browser to the application
4. The employee directory page should load (the one Mike built in 2000)

**Reality check**: Getting a full ADF application to run takes configuration. The database connection, the ADF model bindings, the WebLogic domain setup — there's a lot. For a PoC showcase, reading the code is usually the better ROI.

---

## What Each File Does (Quick Reference)

### Database Layer (`Model/database/`)

| Directory | What's in it | Time-era tells |
|-----------|-------------|----------------|
| `2000_foundation/` | EMPLOYEES, INVENTORY_ITEMS, PKG_STORE_OPS, seed data | Natural keys, CHAR flags, "everything in one package" |
| `2003_expansion/` | STORES, MENU_ITEMS, ORDERS, sp_OrderProcessing, payroll | Surrogate keys, sp_ prefix, first duplication |
| `2006_franchise/` | FRANCHISES, SUPPLIERS, franchise/supplier packages | Third naming convention, unfinished junction table |
| `2009_web_ordering/` | CUSTOMERS, ONLINE_ORDERS, WEB_ORDER_PKG | 3-level nesting, pseudo-JSON parser, parallel order tables |
| `2012_loyalty_mobile/` | LOYALTY_POINTS, REWARDS, MOBILE_SESSIONS, loyalty/mobile pkgs | camelCase procs, triple-nested cursors, duplicate lookup |
| `2015_analytics/` | Reporting package, materialized views | Absurd package name, temp tables, lost source code |
| `2018_modernization/` | API wrappers, abandoned microservice | 5-level call chain, empty UUID-based USERS table |
| `2020_delivery/` | DELIVERY_PKG, DELIVERY_ORDERS, drivers | Copy-pasted code, NO-OP procedures, known bugs |
| `2023_current/` | Known issues inventory | Tech debt catalog, call chain map, "don't touch" list |

### Java Layer (`Model/src/model/`)

| Package | What's in it |
|---------|-------------|
| `entities/` | EmployeeEOImpl, OrderEOImpl, InventoryItemEOImpl — ADF Entity Objects with era comments |
| `services/` | StoreOpsAMImpl (Mike's 140-method monolith), OrderServiceAMImpl (Sarah's cleaner separation) |
| `rest/` | OrderRestController (half-finished 2018 modernization), DeliveryController (empty 2020 stub) |
| `util/` | LegacyDateUtils (Mike, rounds DOWN) vs DateHelper (Sarah, rounds UP) — the $8,000 lawsuit |

### UI Layer (`ViewController/`)

| File | Era | Story |
|------|-----|-------|
| `employeeDirectory.jspx` | 2000 | Original drag-and-drop ADF page, drag-and-drop, still in production |
| `franchiseDashboard.jspx` | 2006 | 12 panels, 4 tabs, mystery export button nobody can delete |
| `deliveryTracker.jspx` | 2020 | Copy-pasted from loyalty page, "Beta" for 3 years, hidden dead elements |
| `EmployeeBean.java` | 2000 | Original managed bean pattern — copied 6 times by subsequent teams |
| `FranchiseDashboardBean.java` | 2006 | 800+ line blob, 40+ fields from 3 different teams |
| `DeliveryTrackerBean.java` | 2020 | Copy-paste chain 5 generations deep, unused loyalty fields can't be removed |

---

## "I just want to see the coolest parts"

Read these files in order. They tell the story through the code itself:

1. **`LEGACY_HISTORY.md`** — the full narrative (15 min read)
2. **`2000_foundation/02_pkg_store_ops.sql`** — see the clean, simple origin
3. **`2003_expansion/02_sp_order_processing.sql`** — watch the first duplication happen
4. **`2009_web_ordering/02_web_order_pkg.sql`** — the deep nesting begins (read the comments!)
5. **`2012_loyalty_mobile/02_loyalty_pkg.sql`** — triple-nested cursor loop, 45-min runtime
6. **`2018_modernization/02_abandoned_microservice.sql`** — the future that never happened
7. **`2023_current/01_known_issues.sql`** — the bill coming due
8. **`Model/src/model/util/LegacyDateUtils.java`** vs **`DateHelper.java`** — two date classes, one $8K lawsuit
