-- ============================================================
-- BurgerQuick Expansion Schema - 2003
-- Author: Sarah Mitchell (Senior Developer)
-- ============================================================
-- Added stores, menu, and ordering tables.
-- Using surrogate keys (IDs) instead of natural keys like Mike.
-- Added foreign keys. Mike's original tables didn't have any!
-- - Sarah
-- ============================================================

CREATE TABLE STORES (
    store_id        NUMBER PRIMARY KEY,
    store_number    VARCHAR2(5) UNIQUE NOT NULL,
    store_name      VARCHAR2(100),
    address_line1   VARCHAR2(100),
    city            VARCHAR2(50),
    state           VARCHAR2(2),
    zip             VARCHAR2(10),
    phone           VARCHAR2(15),
    manager_id      VARCHAR2(10),  -- FK to EMPLOYEES, not enforced yet
    open_date       DATE,
    seating_capacity NUMBER DEFAULT 50,
    drive_thru_yn   CHAR(1) DEFAULT 'Y',  -- Sarah uses _YN suffix vs Mike's is_active
    is_open         CHAR(1) DEFAULT 'Y',
    created_dt      DATE DEFAULT SYSDATE,   -- Sarah uses _dt suffix vs Mike's created_date
    created_by      VARCHAR2(30) DEFAULT 'SARAH'
);

CREATE TABLE MENU_ITEMS (
    menu_item_id    NUMBER PRIMARY KEY,
    item_code       VARCHAR2(10) UNIQUE,     -- e.g., 'BQ-BASIC', 'BQ-DBL'
    display_name    VARCHAR2(100) NOT NULL,
    description     VARCHAR2(500),
    category        VARCHAR2(30),             -- Burger, Side, Drink, Dessert
    base_price      NUMBER(6,2),
    cost_to_make    NUMBER(6,2),
    is_available    CHAR(1) DEFAULT 'Y',
    display_order   NUMBER DEFAULT 0,
    created_dt      DATE DEFAULT SYSDATE,
    created_by      VARCHAR2(30) DEFAULT 'SARAH'
);

CREATE TABLE ORDERS (
    order_id        NUMBER PRIMARY KEY,
    store_id        NUMBER NOT NULL,
    order_dt        DATE DEFAULT SYSDATE,
    order_type      VARCHAR2(10),  -- 'DINE_IN', 'TAKEOUT', 'DRIVE_THRU'
    total_amount    NUMBER(8,2),
    tax_amount      NUMBER(8,2),
    payment_method  VARCHAR2(20),  -- 'CASH', 'CREDIT', 'CHECK'
    employee_id     VARCHAR2(10),  -- Cashier who took the order
    status          VARCHAR2(20) DEFAULT 'NEW',
    created_dt      DATE DEFAULT SYSDATE,
    created_by      VARCHAR2(30) DEFAULT 'SARAH',
    CONSTRAINT fk_order_store FOREIGN KEY (store_id) REFERENCES STORES(store_id)
);

CREATE TABLE ORDER_ITEMS (
    order_item_id   NUMBER PRIMARY KEY,
    order_id        NUMBER NOT NULL,
    menu_item_id    NUMBER NOT NULL,
    quantity        NUMBER DEFAULT 1,
    unit_price      NUMBER(6,2),  -- Price at time of order (can change later)
    special_instructions VARCHAR2(200),
    created_dt      DATE DEFAULT SYSDATE,
    CONSTRAINT fk_oi_order FOREIGN KEY (order_id) REFERENCES ORDERS(order_id),
    CONSTRAINT fk_oi_menu FOREIGN KEY (menu_item_id) REFERENCES MENU_ITEMS(menu_item_id)
);

-- Sarah noticed Mike didn't create sequences. She adds them.
CREATE SEQUENCE seq_store_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_menu_item_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_order_id START WITH 1000 INCREMENT BY 1;
CREATE SEQUENCE seq_order_item_id START WITH 1 INCREMENT BY 1;
