-- ============================================================
-- BurgerQuick Foundation Schema - 2000
-- Author: Mike Henderson (Sole DBA/Developer)
-- ============================================================
-- Mike's Notes:
-- Keeping it simple. Two tables to start. We can always add more later.
-- Using natural keys where possible - surrogate keys add complexity.
-- All business logic goes in the database. Apps are just for display.
-- ============================================================

CREATE TABLE EMPLOYEES (
    employee_id     VARCHAR2(11) PRIMARY KEY,  -- Format: BQ-EMP-0001 (fixed: 11 chars, not 10. Mike couldn't count.)
    first_name      VARCHAR2(50) NOT NULL,
    last_name       VARCHAR2(50) NOT NULL,
    ssn             VARCHAR2(11),              -- Stored as plain text, it's fine
    hire_date       DATE DEFAULT SYSDATE,
    store_number    VARCHAR2(5),               -- FK to STORES table (coming soon)
    position        VARCHAR2(30),
    hourly_rate     NUMBER(6,2),
    manager_id      VARCHAR2(11),              -- Self-referencing FK (same format as employee_id)
    phone           VARCHAR2(15),
    address_line1   VARCHAR2(100),
    city            VARCHAR2(50),
    state           VARCHAR2(2),
    zip             VARCHAR2(10),
    is_active       CHAR(1) DEFAULT 'Y',       -- Mike likes CHAR for flags
    created_date    DATE DEFAULT SYSDATE,
    created_by      VARCHAR2(30) DEFAULT 'MIKE'
);

CREATE TABLE INVENTORY_ITEMS (
    item_sku        VARCHAR2(15) PRIMARY KEY,  -- SKU as PK, simple
    item_name       VARCHAR2(100) NOT NULL,
    category        VARCHAR2(30),
    unit_type       VARCHAR2(10),              -- 'LB', 'EACH', 'CASE'
    par_level       NUMBER(8,2),              -- Minimum level before reorder
    current_qty     NUMBER(8,2),
    unit_cost       NUMBER(8,4),
    supplier_name   VARCHAR2(100),
    supplier_phone  VARCHAR2(15),
    last_order_date DATE,
    is_active       CHAR(1) DEFAULT 'Y',
    created_date    DATE DEFAULT SYSDATE,
    created_by      VARCHAR2(30) DEFAULT 'MIKE'
);

-- Mike's simple audit log - just one table for everything
CREATE TABLE AUDIT_LOG (
    log_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name  VARCHAR2(50),
    action      VARCHAR2(10),  -- INSERT, UPDATE, DELETE
    record_key  VARCHAR2(50),
    changed_by  VARCHAR2(30),
    change_date DATE DEFAULT SYSDATE,
    old_values  VARCHAR2(4000),
    new_values  VARCHAR2(4000)
);
