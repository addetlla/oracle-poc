# BurgerQuick Systems

**Enterprise Resource Management Application**

Version 9.0 | Oracle ADF 12c | Oracle Database 19c

---

## Quickest: Just Read the Code

This is an Oracle ADF application — there's no `npm install && npm start`. The PoC is designed to be read. Start here:

```
1. Model/database/           <- Trace the evolution era by era
2. Model/src/model/          <- Java business layer with era-specific comments
3. ViewController/           <- UI pages and managed beans
```

---

## Overview

BurgerQuick Systems is the operational backbone for BurgerQuick, a regional quick-service restaurant chain with 200+ locations across 14 states and approximately 12,000 employees. The application manages core business functions including employee administration, order processing, inventory control, franchise management, loyalty programs, mobile ordering, delivery logistics, and business intelligence reporting.

The system processes over 10,000 orders daily across multiple sales channels: point-of-sale (POS), web, mobile, and delivery.

---

## Technology Stack

| Layer                     | Technology                                                    |
| ------------------------- | ------------------------------------------------------------- |
| **Application Framework** | Oracle ADF 12c (12.2.1.4)                                     |
| **IDE**                   | Oracle JDeveloper 12c                                         |
| **Application Server**    | Oracle WebLogic Server                                        |
| **Database**              | Oracle Database 19c / 21c                                     |
| **Business Logic**        | PL/SQL (stored procedures and packages)                       |
| **View Layer**            | ADF Faces (JSF 2.x, `.jspx` pages)                            |
| **Model Layer**           | ADF Business Components (Entity Objects, Application Modules) |
| **Language**              | Java 8, PL/SQL                                                |

---

## Architecture

The application follows Oracle ADF's Model-View-Controller architecture:

```
┌─────────────────────────────────────────────────┐
│  Browser / Mobile Client / POS Terminal         │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│  ViewController (ADF Faces / JSF)               │
│  • .jspx pages                                  │
│  • Managed Beans (Java)                         │
│  • Data Bindings (.pageDef.xml)                 │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│  Model (ADF Business Components)                │
│  • Entity Objects (EO)                          │
│  • Application Modules (AM)                     │
│  • View Objects (VO)                            │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│  Database (Oracle 19c)                          │
│  • PL/SQL Packages & Stored Procedures          │
│  • Tables, Views, Materialized Views            │
│  • Scheduler Jobs                               │
└─────────────────────────────────────────────────┘
```

Business logic is database-centric by design. PL/SQL packages and stored procedures enforce all business rules, data integrity, and transactional boundaries. The Java and ADF layers serve as the presentation and data-binding tier.

---

#### Queue Architecture

Two Oracle AQ queues handle the delivery lifecycle. The first is a work queue; the second is a pub/sub broadcast queue that feeds the dashboard.

```
                        CREATE DELIVERY
                              │
                              ▼
              ┌───────────────────────────────┐
              │     inv_delivery_queue        │  ◀── single-consumer work queue
              │   (one message per delivery)  │
              │                               │
              │   status_at_enqueue: PENDING  │
              └──────────────┬────────────────┘
                             │
              ┌──────────────┴────────────────┐
              │     inv_broadcast_queue       │  ◀── multi-consumer pub/sub queue
              │  (new message per transition) │
              │                               │
              │   subscribers:                │
              │   • DASHBOARD_METRICS_AGENT ✓ │  ◀── async callback wired up
              │   • DELIVERY_FULFILLMENT_AGENT│      (placeholder, not yet impl)
              └──────────────┬────────────────┘
                             │
                             ▼
              ┌───────────────────────────────┐
              │  sync_dashboard_metrics_cb    │  ◀── PL/SQL callback (AQ notification)
              │                               │
              │  PENDING    → pending += 1    │
              │  COMPLETED  → pending -= 1    │
              │               fulfilled += 1  │
              │  CANCELLED  → pending -= 1    │
              └──────────────┬────────────────┘
                             │
                             ▼
              ┌───────────────────────────────┐
              │      INVENTORY_DELIVERIES     │  ◀── source-of-truth table
              │                               │
              │  DashboardBean queries this   │
              │  directly every 3s via poll   │
              └───────────────────────────────┘
```

**How messages flow:**

| Step             | What happens                                                                                                                            |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Create delivery  | Row inserted with `status='PENDING'`. One message enqueued to **both** queues.                                                          |
| Fulfill delivery | Inventory updated. Status → `'COMPLETED'`. Original message dequeued from work queue. New `COMPLETED` message broadcast.                |
| Cancel delivery  | Status → `'CANCELLED'`. New `CANCELLED` message broadcast. (Note: original work-queue message is never dequeued on cancel — known gap.) |

The `inv_delivery_queue` message acts as a lock — it's dequeued by `aq_msg_id` during fulfillment. The `inv_broadcast_queue` messages are fire-and-forget: each status transition pushes a new message, and the `DASHBOARD_METRICS_AGENT` subscriber dequeues it immediately via the async callback to update dashboard counters.

**Why the dashboard queries the table directly:** The AQ callback updates a `DASHBOARD_STATS` pre-aggregation table, but delivering those callbacks requires `job_queue_processes > 0` (Oracle background jobs). In dev environments this is often 0, so `DashboardBean` queries `INVENTORY_DELIVERIES` directly — bypassing the callback dependency entirely.

---

## Project Structure

```
Application1/
├── Application1.jws                  # JDeveloper workspace
├── .adf/                             # ADF framework configuration
│   └── META-INF/adf-config.xml       # Data bindings, locking, PPR settings
├── Model/                            # ADF Model project
│   ├── Model.jpr                     # JDeveloper project file
│   ├── database/                     # PL/SQL source (organized by era)
│   │   ├── 2000_foundation/          # Employees, inventory, store ops
│   │   ├── 2003_expansion/           # Stores, menus, orders, payroll
│   │   ├── 2006_franchise/           # Franchises, suppliers
│   │   ├── 2009_web_ordering/        # Customers, online orders
│   │   ├── 2012_loyalty_mobile/      # Loyalty points, mobile services
│   │   ├── 2015_analytics/           # Reporting, materialized views
│   │   ├── 2018_modernization/       # REST API wrappers
│   │   ├── 2020_delivery/            # Delivery orders, drivers
│   │   └── 2023_current/             # Known issues, current PKG_STORE_OPS
│   └── src/model/                    # Java business layer
│       ├── entities/                 # ADF Entity Object implementations
│       ├── services/                 # Application Module implementations
│       ├── rest/                     # REST controllers
│       └── util/                     # Date utilities, helpers
├── ViewController/                   # ADF ViewController project
│   ├── ViewController.jpr            # JDeveloper project file
│   ├── public_html/pages/            # .jspx page files
│   └── src/view/beans/               # Managed beans (Java backing beans)
├── build.sh                          # Headless build and deploy script
├── install_all.sql                   # Full database bootstrap script
├── install_all_dbeaver.sql           # DBeaver-compatible bootstrap
├── LEGACY_HISTORY.md                 # Technical history and developer field guide
└── RUNNING.md                        # Setup and execution instructions
```

---

## Key Database Objects

| Object                              | Type    | Purpose                                            |
| ----------------------------------- | ------- | -------------------------------------------------- |
| `PKG_STORE_OPS`                     | Package | Core store operations: employees, inventory, audit |
| `sp_OrderProcessing`                | Package | Order lifecycle: create, complete, cancel          |
| `WEB_ORDER_PKG`                     | Package | Online order placement and processing              |
| `LOYALTY_PKG`                       | Package | Loyalty points, rewards, nightly recalculation     |
| `p_MobileOps`                       | Package | Mobile app backend operations                      |
| `FRANCHISE_PKG`                     | Package | Franchise owner and location management            |
| `SUPPLIER_PKG`                      | Package | Supplier and procurement operations                |
| `DELIVERY_PKG`                      | Package | Delivery order assignment and tracking             |
| `DELIVERY_ENHANCEMENT_PKG`          | Package | Inventory supply deliveries with Oracle AQ queues  |
| `API_ORDER_SERVICE`                 | Package | REST API wrappers for order procedures             |
| `RPT_DAILY_SALES_V2_FINAL_USE_THIS` | Package | Daily sales reporting                              |

**Total**: 20+ tables, 15 PL/SQL packages, 40+ stored procedures, 30+ Java classes, 15+ JSF pages.

---

## Setup & Installation

See [RUNNING.md](RUNNING.md) for full details. Quick summary below.

### Prerequisites

- **JDK 8** (bundled with JDeveloper at `$MW_HOME/oracle_common/jdk`)
- **Oracle JDeveloper 12c** (12.2.1.4) — provides `ojdeploy` (headless build tool) and the integrated WebLogic server
- **Oracle Database** 19c or 21c (Express Edition recommended for development)

### Step 1: Get Oracle Database

**Option A — Docker (easiest):**
```bash
docker run -d --name oracle-xe \
  -p 1521:1521 -p 5500:5500 \
  -e ORACLE_PASSWORD=burgerquick \
  container-registry.oracle.com/database/express:21.3.0-xe
```

**Option B — Oracle XE (free, local):** Download [Oracle Database XE 21c](https://www.oracle.com/database/technologies/xe-downloads.html) and install the RPM or Windows installer. Creates a database called `XEPDB1`.

**Option C — Oracle Autonomous Database (cloud, free tier):** Sign up at oracle.com/cloud/free, create an "Always Free" Autonomous Database, and use SQL Developer Web to run scripts.

### Step 2: Run the SQL scripts

```bash
# Using SQL*Plus (command-line tool that comes with Oracle):
sqlplus system/yourpassword@localhost:1521/XEPDB1

# Then at the SQL> prompt:
SQL> @install_all.sql
```

Or use Oracle SQL Developer (free GUI tool) — open `install_all.sql` and run (F5).

After running the script, you'll have 20+ tables with seed data and 9 PL/SQL packages. You can test procedures directly:
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
```

### Step 3: Build and Deploy the Application

**Terminal (no GUI needed):**
```bash
# 1. Start WebLogic (if not already running)
nohup ~/.jdeveloper/system*/DefaultDomain/startWebLogic.sh > /tmp/wls.log 2>&1 &

# 2. Build and deploy
./build.sh

# 3. Open the app
# http://127.0.0.1:7101/ViewController/faces/pages/employeeDirectory.jspx
```

What `build.sh` does:

| Step         | Tool       | What Happens                                                                          |
| ------------ | ---------- | ------------------------------------------------------------------------------------- |
| Compile Java | `ojdeploy` | Compiles Model + ViewController projects, runs dependency analysis                    |
| Package WAR  | `ojdeploy` | Writes `ViewController/deploy/Application1_ViewController_webapp.war`                 |
| Package EAR  | `ojdeploy` | Writes `deploy/Application1_Project1_Application1.ear` (WAR + ADF libs + descriptors) |
| Deploy       | Autodeploy | Copies EAR to WebLogic's `autodeploy/` directory — WebLogic hot-deploys in seconds    |

Override paths via env vars: `MW_HOME=/other/path OJDEPLOY=/other/ojdeploy ./build.sh`

**Critical build warning — the classpath trap:** If you write custom build scripts, exclude JDeveloper design-time JARs (`-dt.jar` suffix, `oracle.bali.*` classes, `bali_share.jar`). If these end up in `WEB-INF/lib`, WebLogic will throw `java.lang.NoClassDefFoundError: oracle/bali/xml/share/WeakListenerManager` at deployment time.

**Or via JDeveloper GUI:** Open `Application1.jws` → configure database connection in Window → Databases → right-click ViewController → Run.

### Ports

| Port | Purpose                                         |
| ---- | ----------------------------------------------- |
| 7100 | HTTP (app)                                      |
| 7101 | Admin Console (`http://127.0.0.1:7101/console`) |
| 7102 | SSL                                             |

### Deploy to a Headless Ubuntu Server

JDeveloper is the IDE — you don't install it on a production server. What runs the app is **Oracle WebLogic Server**, which is fully terminal-friendly.

```
Your Dev Machine                    Your Ubuntu Server
------------------                  ------------------
JDeveloper (GUI IDE)                WebLogic Server (terminal only)
  |                                   |
  +- Write code                       +- Run the EAR/WAR
  +- Build EAR via build.sh           +- Serve pages to users
  +- Deploy EAR ---------------->     +- Connect to Oracle DB
```

| What                  | Where it runs          | GUI needed?                               |
| --------------------- | ---------------------- | ----------------------------------------- |
| JDeveloper IDE        | Your workstation       | Yes                                       |
| WebLogic Server       | Ubuntu server          | No — fully CLI                            |
| Oracle DB             | Ubuntu server          | No — SQL*Plus/CLI                         |
| EAR deployment        | Ubuntu server          | No — WLST or autodeploy                   |
| `build.sh` (ojdeploy) | Your workstation or CI | No — needs JDeveloper install, but no GUI |

The build (ojdeploy) requires a JDeveloper installation even when run headless, so most teams build on a dev machine or CI server and deploy the EAR artifact to the headless server. Running the full ADF application also requires the JRF (Fusion Middleware) domain type — a vanilla WebLogic domain is not sufficient, and RCU must target the pluggable database (e.g. `XEPDB1`), not the root container.

---

## Development History

This application has been in continuous production since 2000, evolving from a single-store system to a 200+ location enterprise platform. Development occurred in distinct phases:

| Period       | Initiative       | Key Contributions                          |
| ------------ | ---------------- | ------------------------------------------ |
| 2000         | Foundation       | Core employee and inventory management     |
| 2003         | Expansion        | Order processing, menu management, payroll |
| 2006         | Franchising      | Franchise and supplier management          |
| 2009         | Web Ordering     | Customer-facing online ordering            |
| 2012         | Mobile & Loyalty | Loyalty program, mobile app backend        |
| 2015         | Analytics        | Business intelligence and reporting        |
| 2018         | Modernization    | REST API layer (partial)                   |
| 2020         | Delivery         | Emergency pandemic delivery module         |
| 2026         | Queue System     | Inventory delivery with Oracle AQ pub/sub  |
| 2023–Present | Maintenance      | Documentation, known issues cataloging     |

A detailed technical history and developer field guide is available in [LEGACY_HISTORY.md](LEGACY_HISTORY.md).

## License

Proprietary. All rights reserved. BurgerQuick Systems.
