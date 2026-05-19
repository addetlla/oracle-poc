# BurgerQuick Systems

**Enterprise Resource Management Application**

Version 9.0 | Oracle ADF 12c | Oracle Database 19c

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

The business logic is database-centric by design. PL/SQL packages and stored procedures enforce all business rules, data integrity, and transactional boundaries. The Java and ADF layers serve as the presentation and data-binding tier.

---

## Modules

### Employee Management (2000)
- Employee directory, hiring, role assignment, and payroll
- `PKG_STORE_OPS` package: hire_employee, update_employee, and related procedures
- `employeeDirectory.jspx` — web-based employee listing and management

### Inventory & Store Operations (2000)
- Inventory tracking with audit logging
- SKU-based stock management across all locations
- Central procedure: `PKG_STORE_OPS.update_inventory`

### Order Processing (2003)
- In-store POS order entry and fulfillment
- `sp_OrderProcessing`: order creation, completion, cancellation
- `ORDERS`, `ORDER_ITEMS`, `MENU_ITEMS` tables

### Franchise Management (2006)
- Franchise owner and location administration
- Supplier relationship management and procurement tracking
- `FRANCHISES`, `FRANCHISE_OWNERS`, `SUPPLIERS` tables

### Web Ordering (2009)
- Customer-facing online ordering platform
- Customer registration and account management
- `WEB_ORDER_PKG.place_online_order`: 3-level nested call chain to inventory
- `CUSTOMERS`, `ONLINE_ORDERS`, `ONLINE_ORDER_ITEMS` tables

### Loyalty & Mobile (2012)
- Customer loyalty points program with rewards redemption
- Mobile application backend services
- `LOYALTY_PKG`, `p_MobileOps`: authentication, nearby store lookup, mobile ordering
- Nightly loyalty points recalculation process

### Business Intelligence (2015)
- Sales reporting and analytics
- Materialized views for dashboard performance
- `RPT_DAILY_SALES_V2_FINAL_USE_THIS` — primary daily sales reporting package

### API Layer (2018)
- REST API wrappers for legacy stored procedures
- `API_ORDER_SERVICE`: REST-friendly interface to existing order operations
- Designed for incremental modernization via the Strangler Fig pattern

### Delivery Management (2020)
- Delivery order tracking and driver assignment
- `DELIVERY_PKG`, `DELIVERY_ORDERS`, `DELIVERY_DRIVERS`
- `deliveryTracker.jspx` — real-time delivery monitoring dashboard

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
| `API_ORDER_SERVICE`                 | Package | REST API wrappers for order procedures             |
| `RPT_DAILY_SALES_V2_FINAL_USE_THIS` | Package | Daily sales reporting                              |

**Total**: 20+ tables, 15 PL/SQL packages, 40+ stored procedures, 30+ Java classes, 15+ JSF pages.

---

## Setup & Installation

See [RUNNING.md](RUNNING.md) for full details. Quick summary below.

### Prerequisites

- JDK 8
- Oracle JDeveloper 12c (12.2.1.4) — provides the build tools and integrated WebLogic server
- Oracle Database 19c or 21c (Express Edition recommended for development)

### Quick Start — Database

```bash
# Docker (easiest)
docker run -d --name oracle-xe -p 1521:1521 \
  -e ORACLE_PASSWORD=burgerquick \
  container-registry.oracle.com/database/express:21.3.0-xe

# Then run the bootstrap
sqlplus system/burgerquick@localhost:1521/XEPDB1 @install_all.sql
```

### Quick Start — Application

**Terminal (no GUI needed):**
```bash
# Start WebLogic, then:
./build.sh
# Open http://127.0.0.1:7101/ViewController/faces/pages/employeeDirectory.jspx
```

**Or via JDeveloper GUI:** Open `Application1.jws` → right-click ViewController → Run.

Both approaches are covered in detail in [RUNNING.md](RUNNING.md), including how to deploy to a headless Ubuntu server.

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
| 2023–Present | Maintenance      | Documentation, known issues cataloging     |

A detailed technical history and developer field guide is available in [LEGACY_HISTORY.md](LEGACY_HISTORY.md).

---

## Known Considerations

- **Call chain depth**: Order placement traverses up to 5 layers of nested procedure calls (API → Web → Orders → Completion → Inventory). Trace to `PKG_STORE_OPS` to reach the root.
- **Naming conventions**: The database contains multiple naming styles from different development periods. See the field guide in LEGACY_HISTORY.md.
- **Critical path**: `PKG_STORE_OPS.update_inventory` is called by all sales channels. Modifications require extensive regression testing.
- **The `USERS` table** (2018) is an incomplete modernization artifact and is not the active user table.

---

## License

Proprietary. All rights reserved. BurgerQuick Systems.
