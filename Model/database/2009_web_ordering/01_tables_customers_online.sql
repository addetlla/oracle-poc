-- ============================================================
-- Online Ordering Tables - 2009
-- Author: Jason Miller (Web Developer)
-- ============================================================
-- I'm a Java/JSF developer, not a DBA. These tables are based
-- on what the web app needs. I'm sure the naming is fine.
-- ============================================================

CREATE TABLE CUSTOMERS (
    cust_id         NUMBER PRIMARY KEY,
    first_name      VARCHAR2(50),
    last_name       VARCHAR2(50),
    email           VARCHAR2(100) UNIQUE,
    phone           VARCHAR2(15),
    password_hash   VARCHAR2(64),   -- SHA-256 (I think? Tom in IT set this up)
    address_line1   VARCHAR2(100),
    city            VARCHAR2(50),
    state           VARCHAR2(2),
    zip             VARCHAR2(10),
    registered_date DATE DEFAULT SYSDATE,
    last_login      DATE,
    is_active       CHAR(1) DEFAULT 'Y',   -- Using Mike's convention here
    CONSTRAINT pk_customers PRIMARY KEY (cust_id)
);

CREATE TABLE ONLINE_ORDERS (
    online_order_id NUMBER PRIMARY KEY,
    cust_id         NUMBER NOT NULL,
    store_id        NUMBER NOT NULL,
    order_date      DATE DEFAULT SYSDATE,
    pickup_time     DATE,           -- Estimated pickup time
    order_type      VARCHAR2(20) DEFAULT 'PICKUP',  -- PICKUP, DELIVERY (added 2012)
    subtotal        NUMBER(8,2),
    tax             NUMBER(8,2),
    tip             NUMBER(8,2),
    total           NUMBER(8,2),
    payment_type    VARCHAR2(20),
    payment_ref     VARCHAR2(100),  -- Last 4 digits or PayPal ref
    status          VARCHAR2(20) DEFAULT 'RECEIVED',
    -- RECEIVED -> CONFIRMED -> PREPARING -> READY -> PICKED_UP / CANCELLED

    -- Jason's note: I know ORDERS table already exists but it's for in-store.
    -- The web flow is different. Different statuses, payment flow, etc.
    -- Sarah said to use ORDERS but it didn't have the fields I needed
    -- and I didn't want to break the POS system which depends on ORDERS.
    CONSTRAINT pk_online_orders PRIMARY KEY (online_order_id),
    CONSTRAINT fk_oo_cust FOREIGN KEY (cust_id) REFERENCES CUSTOMERS(cust_id),
    CONSTRAINT fk_oo_store FOREIGN KEY (store_id) REFERENCES STORES(store_id)
);

CREATE TABLE ONLINE_ORDER_ITEMS (
    oo_item_id      NUMBER PRIMARY KEY,
    online_order_id NUMBER NOT NULL,
    menu_item_id    NUMBER NOT NULL,    -- Reusing Sarah's MENU_ITEMS table
    quantity        NUMBER DEFAULT 1,
    special_notes   VARCHAR2(500),
    unit_price      NUMBER(6,2),
    CONSTRAINT pk_oo_items PRIMARY KEY (oo_item_id),
    CONSTRAINT fk_ooi_order FOREIGN KEY (online_order_id) REFERENCES ONLINE_ORDERS(online_order_id),
    CONSTRAINT fk_ooi_menu FOREIGN KEY (menu_item_id) REFERENCES MENU_ITEMS(menu_item_id)
);

CREATE SEQUENCE seq_cust_id START WITH 1000 INCREMENT BY 1;
CREATE SEQUENCE seq_online_order_id START WITH 10000 INCREMENT BY 1;
CREATE SEQUENCE seq_oo_item_id START WITH 1 INCREMENT BY 1;
