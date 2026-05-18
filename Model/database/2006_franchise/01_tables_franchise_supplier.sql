-- ============================================================
-- Franchise Management Tables - 2006
-- Author: Offshore Dev Team Lead (Raj)
-- Team: Raj, Priya, Anil - hired to build franchise module
-- ============================================================
-- We built this based on the requirements doc from corporate.
-- The existing tables were hard to understand so we mostly
-- started fresh with our own conventions.
-- ============================================================

CREATE TABLE FRANCHISES (
    franchise_id    NUMBER,
    franchise_code  VARCHAR2(10),     -- e.g., 'FR-NE-001'
    franchise_name  VARCHAR2(100),
    owner_first_nm  VARCHAR2(50),     -- abbreviated column names to save typing - Raj
    owner_last_nm   VARCHAR2(50),
    owner_phone     VARCHAR2(20),
    owner_email     VARCHAR2(100),
    territory       VARCHAR2(50),     -- 'NORTHEAST', 'SOUTHEAST', etc.
    total_locations NUMBER DEFAULT 1,
    agreement_start DATE,
    agreement_end   DATE,
    royalty_pct     NUMBER(5,2),      -- e.g., 5.50 = 5.5%
    status          VARCHAR2(20) DEFAULT 'ACTIVE',
    create_date     DATE DEFAULT SYSDATE,
    create_user     VARCHAR2(30) DEFAULT 'RAJ',
    last_mod_date   DATE,
    last_mod_user   VARCHAR2(30),
    CONSTRAINT pk_franchises PRIMARY KEY (franchise_id)
);

CREATE TABLE FRANCHISE_OWNERS (
    owner_id        NUMBER,
    first_nm        VARCHAR2(50),     -- Different abbreviation than FRANCHISES.owner_first_nm
    last_nm         VARCHAR2(50),
    ssn             VARCHAR2(11),     -- Stored plain text, same as EMPLOYEES (copying Mike's pattern)
    dob             DATE,
    phone_primary   VARCHAR2(20),     -- Not just 'phone' like EMPLOYEES, more specific
    phone_secondary VARCHAR2(20),     -- EMPLOYEES doesn't have this
    email_addr      VARCHAR2(100),    -- Not just 'email' like FRANCHISES
    address_1       VARCHAR2(100),
    address_2       VARCHAR2(100),
    city            VARCHAR2(50),
    state_cd        VARCHAR2(2),      -- _cd suffix vs others who use full 'state'
    zip_code        VARCHAR2(10),     -- zip_code vs EMPLOYEES.zip (just 'zip')
    notes           VARCHAR2(2000),
    created_date    DATE DEFAULT SYSDATE,
    created_by      VARCHAR2(30) DEFAULT 'PRIYA',
    CONSTRAINT pk_franchise_owners PRIMARY KEY (owner_id)
);

-- This was supposed to be a junction table but we never finished it.
-- The data is duplicated in both FRANCHISES and FRANCHISE_OWNERS instead.
-- TODO: Normalize this - Anil, 2006 (never happened)
CREATE TABLE FRANCHISE_OWNER_LINK (
    link_id         NUMBER,
    franchise_id    NUMBER,
    owner_id        NUMBER,
    ownership_pct   NUMBER(5,2),
    created_date    DATE DEFAULT SYSDATE,
    CONSTRAINT pk_fol PRIMARY KEY (link_id)
);

CREATE TABLE SUPPLIERS (
    supplier_id     NUMBER,
    supplier_cd     VARCHAR2(10),
    company_name    VARCHAR2(100),
    contact_name    VARCHAR2(100),
    contact_phone   VARCHAR2(20),
    contact_email   VARCHAR2(100),
    address_1       VARCHAR2(100),
    city            VARCHAR2(50),
    state           VARCHAR2(2),
    zip             VARCHAR2(10),
    payment_terms   VARCHAR2(50),     -- 'NET30', 'NET60', etc.
    is_approved     CHAR(1) DEFAULT 'N',
    approved_date   DATE,
    approved_by     VARCHAR2(30),
    status          VARCHAR2(20) DEFAULT 'PENDING',
    create_date     DATE DEFAULT SYSDATE,
    create_user     VARCHAR2(30) DEFAULT 'ANIL',
    CONSTRAINT pk_suppliers PRIMARY KEY (supplier_id)
);

CREATE TABLE SUPPLY_ORDERS (
    supply_order_id NUMBER,
    supplier_id     NUMBER NOT NULL,
    store_id        NUMBER,           -- FK to STORES (if store-specific)
    franchise_id    NUMBER,           -- FK to FRANCHISES (if franchise-level)
    order_date      DATE DEFAULT SYSDATE,
    total_amount    NUMBER(10,2),
    delivery_date   DATE,
    status          VARCHAR2(20) DEFAULT 'ORDERED',
    created_date    DATE DEFAULT SYSDATE,
    created_by      VARCHAR2(30) DEFAULT 'RAJ',
    CONSTRAINT pk_supply_orders PRIMARY KEY (supply_order_id),
    CONSTRAINT fk_so_supplier FOREIGN KEY (supplier_id) REFERENCES SUPPLIERS(supplier_id)
);

CREATE TABLE SUPPLY_ORDER_ITEMS (
    soi_id          NUMBER,           -- Abbreviated name, different from ORDER_ITEMS pattern
    supply_order_id NUMBER NOT NULL,
    item_sku        VARCHAR2(15),     -- References INVENTORY_ITEMS.item_sku
    quantity        NUMBER,
    unit_cost       NUMBER(8,4),
    received_qty    NUMBER,           -- How much actually arrived
    received_date   DATE,
    notes           VARCHAR2(500),
    CONSTRAINT pk_soi PRIMARY KEY (soi_id),
    CONSTRAINT fk_soi_order FOREIGN KEY (supply_order_id) REFERENCES SUPPLY_ORDERS(supply_order_id)
);

-- Sequences
CREATE SEQUENCE seq_franchise_id START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE seq_owner_id START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE seq_fol_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_supplier_id START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE seq_supply_order_id START WITH 5000 INCREMENT BY 1;
CREATE SEQUENCE seq_soi_id START WITH 1 INCREMENT BY 1;
