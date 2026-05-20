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
-- ============================================================
-- PKG_STORE_OPS v3 - Added Stores + Inventory CRUD (2025)
-- Builds on v2 (2024) which added get_all_employees, update_employee
-- Now includes full CRUD for STORES and INVENTORY_ITEMS
-- ============================================================

CREATE OR REPLACE PACKAGE PKG_STORE_OPS AS

    -- Employee functions (v1 + v2)
    FUNCTION get_all_employees RETURN SYS_REFCURSOR;
    FUNCTION get_employee(p_emp_id VARCHAR2) RETURN SYS_REFCURSOR;
    FUNCTION find_employees_by_store(p_store_no VARCHAR2) RETURN SYS_REFCURSOR;
    PROCEDURE hire_employee(
        p_first_name VARCHAR2,
        p_last_name VARCHAR2,
        p_ssn VARCHAR2,
        p_store_number VARCHAR2,
        p_position VARCHAR2,
        p_hourly_rate NUMBER
    );
    PROCEDURE update_employee(
        p_emp_id VARCHAR2,
        p_first_name VARCHAR2,
        p_last_name VARCHAR2,
        p_position VARCHAR2,
        p_hourly_rate NUMBER,
        p_store_number VARCHAR2
    );
    PROCEDURE fire_employee(p_emp_id VARCHAR2);

    -- Store functions (v3)
    FUNCTION get_all_stores RETURN SYS_REFCURSOR;
    FUNCTION get_store(p_store_id NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION find_stores_by_city(p_city VARCHAR2) RETURN SYS_REFCURSOR;
    FUNCTION get_next_store_id RETURN NUMBER;
    PROCEDURE create_store(
        p_store_number VARCHAR2,
        p_store_name VARCHAR2,
        p_address VARCHAR2,
        p_city VARCHAR2,
        p_state VARCHAR2,
        p_zip VARCHAR2,
        p_phone VARCHAR2,
        p_manager_id VARCHAR2,
        p_seating_capacity NUMBER,
        p_drive_thru_yn VARCHAR2
    );
    PROCEDURE update_store(
        p_store_id NUMBER,
        p_store_number VARCHAR2,
        p_store_name VARCHAR2,
        p_address VARCHAR2,
        p_city VARCHAR2,
        p_state VARCHAR2,
        p_zip VARCHAR2,
        p_phone VARCHAR2,
        p_manager_id VARCHAR2,
        p_seating_capacity NUMBER,
        p_drive_thru_yn VARCHAR2,
        p_is_open VARCHAR2
    );
    PROCEDURE close_store(p_store_id NUMBER);

    -- Inventory functions (v1 + v3)
    FUNCTION get_inventory_status(p_store_no VARCHAR2) RETURN SYS_REFCURSOR;
    PROCEDURE update_inventory(
        p_sku VARCHAR2,
        p_quantity_change NUMBER,
        p_store_no VARCHAR2
    );
    FUNCTION check_reorder_needed(p_sku VARCHAR2) RETURN CHAR;
    FUNCTION get_all_inventory_items RETURN SYS_REFCURSOR;
    FUNCTION get_inventory_item(p_sku VARCHAR2) RETURN SYS_REFCURSOR;
    FUNCTION find_inventory_by_category(p_category VARCHAR2) RETURN SYS_REFCURSOR;
    PROCEDURE add_inventory_item(
        p_item_sku VARCHAR2,
        p_item_name VARCHAR2,
        p_category VARCHAR2,
        p_unit_type VARCHAR2,
        p_par_level NUMBER,
        p_current_qty NUMBER,
        p_unit_cost NUMBER,
        p_supplier_name VARCHAR2,
        p_supplier_phone VARCHAR2
    );
    PROCEDURE update_inventory_item(
        p_item_sku VARCHAR2,
        p_item_name VARCHAR2,
        p_category VARCHAR2,
        p_unit_type VARCHAR2,
        p_par_level NUMBER,
        p_current_qty NUMBER,
        p_unit_cost NUMBER,
        p_supplier_name VARCHAR2,
        p_supplier_phone VARCHAR2
    );
    PROCEDURE deactivate_inventory_item(p_item_sku VARCHAR2);

    -- General (v1)
    FUNCTION get_next_employee_id RETURN VARCHAR2;
    PROCEDURE log_audit(
        p_table VARCHAR2,
        p_action VARCHAR2,
        p_key VARCHAR2,
        p_old_val VARCHAR2,
        p_new_val VARCHAR2
    );

END PKG_STORE_OPS;
/

CREATE OR REPLACE PACKAGE BODY PKG_STORE_OPS AS

    -- ============================================================
    -- General utilities (v1)
    -- ============================================================

    FUNCTION get_next_employee_id RETURN VARCHAR2 IS
        v_count NUMBER;
        v_new_id VARCHAR2(11);
    BEGIN
        SELECT COUNT(*) + 1 INTO v_count FROM EMPLOYEES;
        v_new_id := 'BQ-EMP-' || LPAD(v_count, 4, '0');
        RETURN v_new_id;
    END;

    PROCEDURE log_audit(
        p_table VARCHAR2,
        p_action VARCHAR2,
        p_key VARCHAR2,
        p_old_val VARCHAR2,
        p_new_val VARCHAR2
    ) IS
    BEGIN
        INSERT INTO AUDIT_LOG (table_name, action, record_key, changed_by, old_values, new_values)
        VALUES (p_table, p_action, p_key, USER, p_old_val, p_new_val);
    END;

    -- ============================================================
    -- Employee CRUD (v1 + v2)
    -- ============================================================

    FUNCTION get_all_employees RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT employee_id, first_name, last_name, position, hourly_rate, store_number
            FROM EMPLOYEES
            WHERE is_active = 'Y'
            ORDER BY employee_id;
        RETURN v_cursor;
    END;

    FUNCTION get_employee(p_emp_id VARCHAR2) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT * FROM EMPLOYEES WHERE employee_id = p_emp_id;
        RETURN v_cursor;
    END;

    FUNCTION find_employees_by_store(p_store_no VARCHAR2) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT employee_id, first_name, last_name, position, hourly_rate, store_number
            FROM EMPLOYEES
            WHERE store_number = p_store_no AND is_active = 'Y'
            ORDER BY employee_id;
        RETURN v_cursor;
    END;

    PROCEDURE hire_employee(
        p_first_name VARCHAR2,
        p_last_name VARCHAR2,
        p_ssn VARCHAR2,
        p_store_number VARCHAR2,
        p_position VARCHAR2,
        p_hourly_rate NUMBER
    ) IS
        v_new_id VARCHAR2(11);
    BEGIN
        v_new_id := get_next_employee_id();
        INSERT INTO EMPLOYEES (employee_id, first_name, last_name, ssn, store_number, position, hourly_rate)
        VALUES (v_new_id, p_first_name, p_last_name, p_ssn, p_store_number, p_position, p_hourly_rate);
        log_audit('EMPLOYEES', 'INSERT', v_new_id, NULL, p_first_name || ' ' || p_last_name);
        COMMIT;
    END;

    PROCEDURE update_employee(
        p_emp_id VARCHAR2,
        p_first_name VARCHAR2,
        p_last_name VARCHAR2,
        p_position VARCHAR2,
        p_hourly_rate NUMBER,
        p_store_number VARCHAR2
    ) IS
    BEGIN
        UPDATE EMPLOYEES
        SET first_name = p_first_name,
            last_name = p_last_name,
            position = p_position,
            hourly_rate = p_hourly_rate,
            store_number = p_store_number
        WHERE employee_id = p_emp_id;
        log_audit('EMPLOYEES', 'UPDATE', p_emp_id, NULL, p_first_name || ' ' || p_last_name);
        COMMIT;
    END;

    PROCEDURE fire_employee(p_emp_id VARCHAR2) IS
    BEGIN
        UPDATE EMPLOYEES SET is_active = 'N' WHERE employee_id = p_emp_id;
        log_audit('EMPLOYEES', 'TERMINATE', p_emp_id, 'Active', 'Inactive');
        COMMIT;
    END;

    -- ============================================================
    -- Store CRUD (v3)
    -- ============================================================

    FUNCTION get_next_store_id RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        SELECT seq_store_id.NEXTVAL INTO v_id FROM DUAL;
        RETURN v_id;
    END;

    FUNCTION get_all_stores RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT store_id, store_number, store_name, address_line1,
                   city, state, zip, phone, manager_id,
                   seating_capacity, drive_thru_yn, is_open
            FROM STORES
            WHERE is_open = 'Y'
            ORDER BY store_number;
        RETURN v_cursor;
    END;

    FUNCTION get_store(p_store_id NUMBER) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT * FROM STORES WHERE store_id = p_store_id;
        RETURN v_cursor;
    END;

    FUNCTION find_stores_by_city(p_city VARCHAR2) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT store_id, store_number, store_name, address_line1,
                   city, state, zip, phone, manager_id,
                   seating_capacity, drive_thru_yn, is_open
            FROM STORES
            WHERE UPPER(city) LIKE '%' || UPPER(p_city) || '%'
              AND is_open = 'Y'
            ORDER BY store_number;
        RETURN v_cursor;
    END;

    PROCEDURE create_store(
        p_store_number VARCHAR2,
        p_store_name VARCHAR2,
        p_address VARCHAR2,
        p_city VARCHAR2,
        p_state VARCHAR2,
        p_zip VARCHAR2,
        p_phone VARCHAR2,
        p_manager_id VARCHAR2,
        p_seating_capacity NUMBER,
        p_drive_thru_yn VARCHAR2
    ) IS
        v_new_id NUMBER;
    BEGIN
        v_new_id := get_next_store_id();
        INSERT INTO STORES (store_id, store_number, store_name, address_line1,
            city, state, zip, phone, manager_id, seating_capacity, drive_thru_yn, created_by)
        VALUES (v_new_id, p_store_number, p_store_name, p_address,
            p_city, p_state, p_zip, p_phone, p_manager_id, p_seating_capacity, p_drive_thru_yn, 'SYSTEM');
        log_audit('STORES', 'INSERT', TO_CHAR(v_new_id), NULL, p_store_number || ' - ' || p_store_name);
        COMMIT;
    END;

    PROCEDURE update_store(
        p_store_id NUMBER,
        p_store_number VARCHAR2,
        p_store_name VARCHAR2,
        p_address VARCHAR2,
        p_city VARCHAR2,
        p_state VARCHAR2,
        p_zip VARCHAR2,
        p_phone VARCHAR2,
        p_manager_id VARCHAR2,
        p_seating_capacity NUMBER,
        p_drive_thru_yn VARCHAR2,
        p_is_open VARCHAR2
    ) IS
    BEGIN
        UPDATE STORES
        SET store_number = p_store_number,
            store_name = p_store_name,
            address_line1 = p_address,
            city = p_city,
            state = p_state,
            zip = p_zip,
            phone = p_phone,
            manager_id = p_manager_id,
            seating_capacity = p_seating_capacity,
            drive_thru_yn = p_drive_thru_yn,
            is_open = p_is_open
        WHERE store_id = p_store_id;
        log_audit('STORES', 'UPDATE', TO_CHAR(p_store_id), NULL, p_store_number || ' - ' || p_store_name);
        COMMIT;
    END;

    PROCEDURE close_store(p_store_id NUMBER) IS
    BEGIN
        UPDATE STORES SET is_open = 'N' WHERE store_id = p_store_id;
        log_audit('STORES', 'CLOSE', TO_CHAR(p_store_id), 'Open', 'Closed');
        COMMIT;
    END;

    -- ============================================================
    -- Inventory CRUD (v1 existing + v3 new)
    -- ============================================================

    FUNCTION get_inventory_status(p_store_no VARCHAR2) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT item_sku, item_name, current_qty, par_level,
                   CASE WHEN current_qty < par_level THEN 'Y' ELSE 'N' END as needs_reorder
            FROM INVENTORY_ITEMS
            WHERE is_active = 'Y';
        RETURN v_cursor;
    END;

    PROCEDURE update_inventory(
        p_sku VARCHAR2,
        p_quantity_change NUMBER,
        p_store_no VARCHAR2
    ) IS
        v_old_qty NUMBER;
        v_new_qty NUMBER;
    BEGIN
        SELECT current_qty INTO v_old_qty FROM INVENTORY_ITEMS WHERE item_sku = p_sku;
        v_new_qty := v_old_qty + p_quantity_change;
        UPDATE INVENTORY_ITEMS SET current_qty = v_new_qty WHERE item_sku = p_sku;
        log_audit('INVENTORY_ITEMS', 'UPDATE', p_sku, TO_CHAR(v_old_qty), TO_CHAR(v_new_qty));
        COMMIT;
    END;

    FUNCTION check_reorder_needed(p_sku VARCHAR2) RETURN CHAR IS
        v_qty NUMBER;
        v_par NUMBER;
    BEGIN
        SELECT current_qty, par_level INTO v_qty, v_par FROM INVENTORY_ITEMS WHERE item_sku = p_sku;
        IF v_qty < v_par THEN RETURN 'Y'; ELSE RETURN 'N'; END IF;
    END;

    FUNCTION get_all_inventory_items RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT item_sku, item_name, category, unit_type,
                   par_level, current_qty, unit_cost,
                   supplier_name, supplier_phone
            FROM INVENTORY_ITEMS
            WHERE is_active = 'Y'
            ORDER BY item_sku;
        RETURN v_cursor;
    END;

    FUNCTION get_inventory_item(p_sku VARCHAR2) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT * FROM INVENTORY_ITEMS WHERE item_sku = p_sku;
        RETURN v_cursor;
    END;

    FUNCTION find_inventory_by_category(p_category VARCHAR2) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT item_sku, item_name, category, unit_type,
                   par_level, current_qty, unit_cost,
                   supplier_name, supplier_phone
            FROM INVENTORY_ITEMS
            WHERE UPPER(category) LIKE '%' || UPPER(p_category) || '%'
              AND is_active = 'Y'
            ORDER BY item_sku;
        RETURN v_cursor;
    END;

    PROCEDURE add_inventory_item(
        p_item_sku VARCHAR2,
        p_item_name VARCHAR2,
        p_category VARCHAR2,
        p_unit_type VARCHAR2,
        p_par_level NUMBER,
        p_current_qty NUMBER,
        p_unit_cost NUMBER,
        p_supplier_name VARCHAR2,
        p_supplier_phone VARCHAR2
    ) IS
    BEGIN
        INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type,
            par_level, current_qty, unit_cost, supplier_name, supplier_phone, created_by)
        VALUES (p_item_sku, p_item_name, p_category, p_unit_type,
            p_par_level, p_current_qty, p_unit_cost, p_supplier_name, p_supplier_phone, 'SYSTEM');
        log_audit('INVENTORY_ITEMS', 'INSERT', p_item_sku, NULL, p_item_name);
        COMMIT;
    END;

    PROCEDURE update_inventory_item(
        p_item_sku VARCHAR2,
        p_item_name VARCHAR2,
        p_category VARCHAR2,
        p_unit_type VARCHAR2,
        p_par_level NUMBER,
        p_current_qty NUMBER,
        p_unit_cost NUMBER,
        p_supplier_name VARCHAR2,
        p_supplier_phone VARCHAR2
    ) IS
    BEGIN
        UPDATE INVENTORY_ITEMS
        SET item_name = p_item_name,
            category = p_category,
            unit_type = p_unit_type,
            par_level = p_par_level,
            current_qty = p_current_qty,
            unit_cost = p_unit_cost,
            supplier_name = p_supplier_name,
            supplier_phone = p_supplier_phone
        WHERE item_sku = p_item_sku;
        log_audit('INVENTORY_ITEMS', 'UPDATE', p_item_sku, NULL, p_item_name);
        COMMIT;
    END;

    PROCEDURE deactivate_inventory_item(p_item_sku VARCHAR2) IS
    BEGIN
        UPDATE INVENTORY_ITEMS SET is_active = 'N' WHERE item_sku = p_item_sku;
        log_audit('INVENTORY_ITEMS', 'DEACTIVATE', p_item_sku, 'Active', 'Inactive');
        COMMIT;
    END;

END PKG_STORE_OPS;
/
-- ============================================================
-- BurgerQuick Seed Data - 2000
-- Just the first store and a few employees to get started
-- ============================================================

-- Initial employees (Store #1 - Flagship location)
INSERT INTO EMPLOYEES (employee_id, first_name, last_name, ssn, store_number, position, hourly_rate)
VALUES ('BQ-EMP-0001', 'Mike', 'Henderson', '123-45-6789', '1', 'Store Manager', 18.50);

INSERT INTO EMPLOYEES (employee_id, first_name, last_name, ssn, store_number, position, hourly_rate, manager_id)
VALUES ('BQ-EMP-0002', 'Tom', 'Reynolds', '234-56-7890', '1', 'Shift Lead', 12.00, 'BQ-EMP-0001');

INSERT INTO EMPLOYEES (employee_id, first_name, last_name, ssn, store_number, position, hourly_rate, manager_id)
VALUES ('BQ-EMP-0003', 'Lisa', 'Chen', '345-67-8901', '1', 'Cashier', 8.50, 'BQ-EMP-0002');

INSERT INTO EMPLOYEES (employee_id, first_name, last_name, ssn, store_number, position, hourly_rate, manager_id)
VALUES ('BQ-EMP-0004', 'James', 'Washington', '456-78-9012', '1', 'Cook', 9.00, 'BQ-EMP-0002');

INSERT INTO EMPLOYEES (employee_id, first_name, last_name, ssn, store_number, position, hourly_rate, manager_id)
VALUES ('BQ-EMP-0005', 'Maria', 'Garcia', '567-89-0123', '1', 'Cashier', 8.50, 'BQ-EMP-0002');

-- Initial inventory items
INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('BEEF-PATTY-4', 'Beef Patty (1/4 lb)', 'Protein', 'EACH', 200, 350, 0.45, 'Midwest Meats Co.');

INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('BUN-SESAME', 'Sesame Seed Bun', 'Bakery', 'EACH', 300, 500, 0.12, 'City Bakery Supply');

INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('LETTUCE-ICE', 'Iceberg Lettuce (shredded)', 'Produce', 'LB', 25, 40, 1.20, 'Fresh Farms Inc.');

INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('TOMATO-SLICE', 'Tomato (sliced)', 'Produce', 'LB', 30, 28, 1.50, 'Fresh Farms Inc.');

INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('FRIES-CRINKLE', 'Crinkle Cut Fries', 'Frozen', 'LB', 100, 80, 0.35, 'Golden Fry Distributors');

INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('SODA-COLA-SYRUP', 'Cola Syrup (5 gal)', 'Beverage', 'EACH', 5, 7, 45.00, 'BevCo');

INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('CHEESE-AMER', 'American Cheese Slice', 'Dairy', 'EACH', 300, 450, 0.08, 'DairyFresh');

INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('PICKLE-CHIPS', 'Pickle Chips', 'Condiments', 'LB', 15, 22, 0.90, 'City Pickle Co.');

COMMIT;
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
    manager_id      VARCHAR2(11),  -- FK to EMPLOYEES, not enforced yet
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
    employee_id     VARCHAR2(11),  -- Cashier who took the order
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
-- ============================================================
-- sp_OrderProcessing - Order Management Procedures
-- Author: Sarah Mitchell, June 2003
-- ============================================================
-- I'm using standalone procedures with sp_ prefix.
-- It's cleaner than one huge package. Each proc does one thing.
-- I do call Mike's PKG_STORE_OPS for inventory updates - no need
-- to rewrite what already works.
-- - Sarah
-- ============================================================

-- NOTE: sp_OrderProcessing is my main order package name BUT it's
-- structured as standalone procs. I know it's confusing. Legacy now.
-- - Sarah, Dec 2003 (yes, I see the irony)

CREATE OR REPLACE PROCEDURE sp_create_order(
    p_store_id      IN NUMBER,
    p_order_type    IN VARCHAR2,
    p_payment_method IN VARCHAR2,
    p_employee_id   IN VARCHAR2,
    p_order_id      OUT NUMBER
) IS
BEGIN
    SELECT seq_order_id.NEXTVAL INTO p_order_id FROM DUAL;

    INSERT INTO ORDERS (order_id, store_id, order_type, payment_method, employee_id, status)
    VALUES (p_order_id, p_store_id, p_order_type, p_payment_method, p_employee_id, 'NEW');

    -- Sarah logs to Mike's audit table
    PKG_STORE_OPS.log_audit('ORDERS', 'INSERT', TO_CHAR(p_order_id), NULL, 'New order created');
    COMMIT;
END sp_create_order;
/

CREATE OR REPLACE PROCEDURE sp_add_order_item(
    p_order_id      IN NUMBER,
    p_menu_item_id  IN NUMBER,
    p_quantity      IN NUMBER,
    p_instructions  IN VARCHAR2 DEFAULT NULL
) IS
    v_unit_price NUMBER(6,2);
    v_item_id NUMBER;
BEGIN
    -- Get current menu price
    SELECT base_price INTO v_unit_price FROM MENU_ITEMS WHERE menu_item_id = p_menu_item_id;

    SELECT seq_order_item_id.NEXTVAL INTO v_item_id FROM DUAL;

    INSERT INTO ORDER_ITEMS (order_item_id, order_id, menu_item_id, quantity, unit_price, special_instructions)
    VALUES (v_item_id, p_order_id, p_menu_item_id, p_quantity, v_unit_price, p_instructions);

    -- Update the order total
    UPDATE ORDERS
    SET total_amount = (SELECT SUM(quantity * unit_price) FROM ORDER_ITEMS WHERE order_id = p_order_id),
        tax_amount = (SELECT SUM(quantity * unit_price) * 0.07 FROM ORDER_ITEMS WHERE order_id = p_order_id)
    WHERE order_id = p_order_id;

    COMMIT;
END sp_add_order_item;
/

CREATE OR REPLACE PROCEDURE sp_complete_order(
    p_order_id IN NUMBER
) IS
    CURSOR c_order_items IS
        SELECT oi.menu_item_id, oi.quantity
        FROM ORDER_ITEMS oi
        WHERE oi.order_id = p_order_id;
    v_sku VARCHAR2(15);
BEGIN
    -- Deduct inventory for each item (simplified mapping)
    -- Sarah: I know this SKU mapping is hardcoded. We'll make a proper
    -- menu-to-inventory mapping table later. For now it works.
    -- UPDATE 2005: Still haven't made that mapping table. It's fine.
    -- UPDATE 2007: Maybe next quarter.
    -- UPDATE 2009: Jason created one in WEB_ORDER_PKG but it maps differently.
    --               See sp_calculate_inventory_usage if you need the mapping.
    -- UPDATE 2012: The agency team created their own mapping in LOYALTY_PKG.inventory_for_reward().
    --               There are now 3 different inventory deduction implementations.
    --               Use sp_complete_order's version for in-store orders. - Sarah (last update before leaving)

    FOR rec IN c_order_items LOOP
        -- Hardcoded menu-item-to-SKU mapping
        IF rec.menu_item_id = 1 THEN v_sku := 'BEEF-PATTY-4';
        ELSIF rec.menu_item_id = 2 THEN v_sku := 'BUN-SESAME';
        ELSIF rec.menu_item_id = 3 THEN v_sku := 'FRIES-CRINKLE';
        END IF;

        IF v_sku IS NOT NULL THEN
            PKG_STORE_OPS.update_inventory(v_sku, -1 * rec.quantity, NULL);
        END IF;
    END LOOP;

    UPDATE ORDERS SET status = 'COMPLETED' WHERE order_id = p_order_id;
    COMMIT;
END sp_complete_order;
/

-- This procedure exists because someone asked for order totals separately.
-- Sarah: I know sp_complete_order already calculates this, but the
-- regional manager wanted a standalone report function.
-- Could've just used a SELECT on ORDERS.total_amount but they wanted a "procedure".
CREATE OR REPLACE FUNCTION sp_get_order_total(
    p_order_id IN NUMBER
) RETURN NUMBER IS
    v_total NUMBER(8,2);
BEGIN
    SELECT SUM(quantity * unit_price)
    INTO v_total
    FROM ORDER_ITEMS
    WHERE order_id = p_order_id;
    RETURN NVL(v_total, 0);
END sp_get_order_total;
/

-- ============================================================
-- PROCEDURE: sp_calculate_inventory_usage
-- Created: Sarah Mitchell, August 2003
-- Purpose: Calculate how much inventory an order consumed
-- NOTE: This duplicates inventory deduction logic from sp_complete_order.
--       I needed a version that doesn't actually deduct, just calculates.
--       Could've used a parameter on sp_complete_order but it was
--       already in production and the manager said "don't touch it."
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_calculate_inventory_usage(
    p_order_id IN NUMBER,
    p_usage_cursor OUT SYS_REFCURSOR
) IS
BEGIN
    -- This is almost identical to the cursor loop in sp_complete_order
    -- but returns the data instead of updating.
    -- If you change the SKU mapping in sp_complete_order, CHANGE IT HERE TOO!
    OPEN p_usage_cursor FOR
        SELECT 'BEEF-PATTY-4' as sku_used, COUNT(*) as qty FROM ORDER_ITEMS
        WHERE order_id = p_order_id AND menu_item_id = 1
        UNION ALL
        SELECT 'BUN-SESAME', COUNT(*) FROM ORDER_ITEMS
        WHERE order_id = p_order_id AND menu_item_id = 2
        UNION ALL
        SELECT 'FRIES-CRINKLE', COUNT(*) FROM ORDER_ITEMS
        WHERE order_id = p_order_id AND menu_item_id = 3;
END sp_calculate_inventory_usage;
/
-- ============================================================
-- Basic Payroll Tracking - 2003
-- Mike started a payroll calculation but never finished.
-- Sarah picked it up and built this. Different style from PKG_STORE_OPS.
-- ============================================================

CREATE TABLE TIME_SHEETS (
    timesheet_id    NUMBER PRIMARY KEY,
    employee_id     VARCHAR2(11) NOT NULL,
    work_date       DATE NOT NULL,
    hours_worked    NUMBER(4,2),
    shift_type      VARCHAR2(10),  -- 'OPEN', 'MID', 'CLOSE'
    approved_yn     CHAR(1) DEFAULT 'N',
    approved_by     VARCHAR2(10),
    created_dt      DATE DEFAULT SYSDATE
);

CREATE SEQUENCE seq_timesheet_id START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PROCEDURE sp_log_hours(
    p_employee_id IN VARCHAR2,
    p_work_date IN DATE,
    p_hours IN NUMBER,
    p_shift IN VARCHAR2
) IS
    v_ts_id NUMBER;
BEGIN
    SELECT seq_timesheet_id.NEXTVAL INTO v_ts_id FROM DUAL;
    INSERT INTO TIME_SHEETS (timesheet_id, employee_id, work_date, hours_worked, shift_type)
    VALUES (v_ts_id, p_employee_id, p_work_date, p_hours, p_shift);
    COMMIT;
END sp_log_hours;
/

-- Payroll calculation proc. Called by the manager every two weeks.
-- Mike wanted this in PKG_STORE_OPS but Sarah said separate concerns.
-- There's still tension about this. See PKG_STORE_OPS for the other
-- employee-related stuff. Yes, employee logic is split across two files.
-- Future developers: sorry. - Sarah
CREATE OR REPLACE PROCEDURE sp_calculate_payroll(
    p_employee_id IN VARCHAR2,
    p_start_date IN DATE,
    p_end_date IN DATE,
    p_total_hours OUT NUMBER,
    p_gross_pay OUT NUMBER
) IS
    v_hourly_rate NUMBER(6,2);
BEGIN
    SELECT NVL(SUM(hours_worked), 0)
    INTO p_total_hours
    FROM TIME_SHEETS
    WHERE employee_id = p_employee_id
      AND work_date BETWEEN p_start_date AND p_end_date;

    SELECT hourly_rate INTO v_hourly_rate
    FROM EMPLOYEES
    WHERE employee_id = p_employee_id;

    p_gross_pay := p_total_hours * v_hourly_rate;
END sp_calculate_payroll;
/
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
-- ============================================================
-- FRANCHISE_PKG - Franchise Management Package
-- Team: Raj, Priya, Anil (Offshore Dev Team)
-- Created: March 2006 | Updated: 2025 (CRUD operations added)
-- ============================================================
-- We used a package like Mike's PKG_STORE_OPS, but our own structure.
-- We call some of Sarah's procs too. Not sure if we should.
-- If something breaks, contact Raj (+91 xxxxx xxxxx).
-- 2025 update adds: get_all_franchises, get_franchise,
--   find_franchises_by_territory, update_franchise, deactivate_franchise
-- ============================================================

CREATE OR REPLACE PACKAGE FRANCHISE_PKG AS

    -- Original (2006)
    PROCEDURE add_franchise(
        p_code VARCHAR2,
        p_name VARCHAR2,
        p_owner_first VARCHAR2,
        p_owner_last VARCHAR2,
        p_territory VARCHAR2,
        p_royalty_pct NUMBER
    );
    PROCEDURE approve_franchise(p_franchise_id NUMBER);
    FUNCTION get_franchise_revenue(p_franchise_id NUMBER, p_year NUMBER)
        RETURN NUMBER;
    FUNCTION calc_royalties(p_franchise_id NUMBER, p_quarter VARCHAR2)
        RETURN NUMBER;
    FUNCTION calculate_franchise_order_total(p_franchise_id NUMBER) RETURN NUMBER;

    -- New CRUD (2025)
    FUNCTION get_all_franchises RETURN SYS_REFCURSOR;
    FUNCTION get_franchise(p_franchise_id NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION find_franchises_by_territory(p_territory VARCHAR2) RETURN SYS_REFCURSOR;
    PROCEDURE update_franchise(
        p_franchise_id NUMBER,
        p_franchise_code VARCHAR2,
        p_franchise_name VARCHAR2,
        p_owner_first VARCHAR2,
        p_owner_last VARCHAR2,
        p_owner_phone VARCHAR2,
        p_owner_email VARCHAR2,
        p_territory VARCHAR2,
        p_total_locations NUMBER,
        p_royalty_pct NUMBER,
        p_agreement_start VARCHAR2,
        p_agreement_end VARCHAR2,
        p_status VARCHAR2
    );
    PROCEDURE deactivate_franchise(p_franchise_id NUMBER);

END FRANCHISE_PKG;
/

CREATE OR REPLACE PACKAGE BODY FRANCHISE_PKG AS

    -- ============================================================
    -- Original procedures (2006)
    -- ============================================================

    PROCEDURE add_franchise(
        p_code VARCHAR2,
        p_name VARCHAR2,
        p_owner_first VARCHAR2,
        p_owner_last VARCHAR2,
        p_territory VARCHAR2,
        p_royalty_pct NUMBER
    ) IS
        v_franchise_id NUMBER;
        v_owner_id NUMBER;
    BEGIN
        SELECT seq_franchise_id.NEXTVAL INTO v_franchise_id FROM DUAL;
        SELECT seq_owner_id.NEXTVAL INTO v_owner_id FROM DUAL;

        INSERT INTO FRANCHISES (franchise_id, franchise_code, franchise_name,
            owner_first_nm, owner_last_nm, territory, royalty_pct, status)
        VALUES (v_franchise_id, p_code, p_name, p_owner_first, p_owner_last,
            p_territory, p_royalty_pct, 'PENDING');

        INSERT INTO FRANCHISE_OWNERS (owner_id, first_nm, last_nm)
        VALUES (v_owner_id, p_owner_first, p_owner_last);

        INSERT INTO FRANCHISE_OWNER_LINK (link_id, franchise_id, owner_id, ownership_pct)
        VALUES (seq_fol_id.NEXTVAL, v_franchise_id, v_owner_id, 100);

        COMMIT;
    END add_franchise;

    PROCEDURE approve_franchise(p_franchise_id NUMBER) IS
    BEGIN
        UPDATE FRANCHISES SET status = 'ACTIVE' WHERE franchise_id = p_franchise_id;
        COMMIT;
    END approve_franchise;

    FUNCTION get_franchise_revenue(p_franchise_id NUMBER, p_year NUMBER)
        RETURN NUMBER IS
        v_total NUMBER(12,2) := 0;
    BEGIN
        SELECT NVL(SUM(o.total_amount), 0)
        INTO v_total
        FROM ORDERS o
        JOIN STORES s ON o.store_id = s.store_id
        WHERE s.store_number IN (
            SELECT store_number FROM STORES s2, FRANCHISES f
            WHERE f.franchise_id = p_franchise_id
              AND s2.city IN (SELECT city FROM STORES)
        )
        AND EXTRACT(YEAR FROM o.order_dt) = p_year;
        RETURN v_total;
    END get_franchise_revenue;

    FUNCTION calc_royalties(p_franchise_id NUMBER, p_quarter VARCHAR2)
        RETURN NUMBER IS
        v_revenue NUMBER(12,2);
        v_royalty_pct NUMBER(5,2);
        v_royalties NUMBER(12,2);
    BEGIN
        v_revenue := get_franchise_revenue(p_franchise_id, 2007);
        SELECT royalty_pct INTO v_royalty_pct
        FROM FRANCHISES WHERE franchise_id = p_franchise_id;
        v_royalties := v_revenue * (v_royalty_pct / 100);
        RETURN v_royalties;
    END calc_royalties;

    FUNCTION calculate_franchise_order_total(p_franchise_id NUMBER)
        RETURN NUMBER IS
        v_total NUMBER(12,2);
    BEGIN
        SELECT NVL(SUM(o.total_amount + o.tax_amount), 0)
        INTO v_total
        FROM ORDERS o
        JOIN STORES s ON o.store_id = s.store_id
        WHERE s.store_number IN (
            SELECT store_number FROM STORES s2, FRANCHISES f
            WHERE f.franchise_id = p_franchise_id
              AND s2.city IN (SELECT city FROM STORES)
        );
        RETURN v_total;
    END calculate_franchise_order_total;

    -- ============================================================
    -- New CRUD procedures (2025)
    -- ============================================================

    FUNCTION get_all_franchises RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT franchise_id, franchise_code, franchise_name,
                   owner_first_nm, owner_last_nm, owner_phone, owner_email,
                   territory, total_locations, royalty_pct,
                   agreement_start, agreement_end, status
            FROM FRANCHISES
            WHERE status != 'INACTIVE'
            ORDER BY franchise_id;
        RETURN v_cursor;
    END;

    FUNCTION get_franchise(p_franchise_id NUMBER) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT * FROM FRANCHISES WHERE franchise_id = p_franchise_id;
        RETURN v_cursor;
    END;

    FUNCTION find_franchises_by_territory(p_territory VARCHAR2) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT franchise_id, franchise_code, franchise_name,
                   owner_first_nm, owner_last_nm, owner_phone, owner_email,
                   territory, total_locations, royalty_pct,
                   agreement_start, agreement_end, status
            FROM FRANCHISES
            WHERE UPPER(territory) LIKE '%' || UPPER(p_territory) || '%'
              AND status != 'INACTIVE'
            ORDER BY franchise_id;
        RETURN v_cursor;
    END;

    PROCEDURE update_franchise(
        p_franchise_id NUMBER,
        p_franchise_code VARCHAR2,
        p_franchise_name VARCHAR2,
        p_owner_first VARCHAR2,
        p_owner_last VARCHAR2,
        p_owner_phone VARCHAR2,
        p_owner_email VARCHAR2,
        p_territory VARCHAR2,
        p_total_locations NUMBER,
        p_royalty_pct NUMBER,
        p_agreement_start VARCHAR2,
        p_agreement_end VARCHAR2,
        p_status VARCHAR2
    ) IS
    BEGIN
        UPDATE FRANCHISES
        SET franchise_code = p_franchise_code,
            franchise_name = p_franchise_name,
            owner_first_nm = p_owner_first,
            owner_last_nm = p_owner_last,
            owner_phone = p_owner_phone,
            owner_email = p_owner_email,
            territory = p_territory,
            total_locations = p_total_locations,
            royalty_pct = p_royalty_pct,
            agreement_start = TO_DATE(p_agreement_start, 'YYYY-MM-DD'),
            agreement_end = TO_DATE(p_agreement_end, 'YYYY-MM-DD'),
            status = p_status,
            last_mod_date = SYSDATE,
            last_mod_user = 'SYSTEM'
        WHERE franchise_id = p_franchise_id;
        COMMIT;
    END;

    PROCEDURE deactivate_franchise(p_franchise_id NUMBER) IS
    BEGIN
        UPDATE FRANCHISES SET status = 'INACTIVE', last_mod_date = SYSDATE, last_mod_user = 'SYSTEM'
        WHERE franchise_id = p_franchise_id;
        COMMIT;
    END;

END FRANCHISE_PKG;
/
-- ============================================================
-- SUPPLIER_PKG - Supplier Management Package
-- Author: Anil (Offshore Dev Team)
-- Created: April 2006
-- ============================================================
-- Similar structure to FRANCHISE_PKG for consistency.
-- Some functions duplicate logic from PKG_STORE_OPS inventory
-- because we needed supplier-specific inventory views.
-- ============================================================

CREATE OR REPLACE PACKAGE SUPPLIER_PKG AS

    PROCEDURE create_supply_order(
        p_supplier_id NUMBER,
        p_store_id NUMBER,
        p_items IN VARCHAR2  -- Comma-separated "SKU:QTY;SKU:QTY" format
    );

    PROCEDURE receive_supply_order(p_supply_order_id NUMBER);

    -- Anil: I know this is similar to PKG_STORE_OPS.update_inventory()
    -- but that procedure doesn't track which supplier the items came from.
    -- We need supplier tracking for franchise reporting.
    PROCEDURE receive_inventory_from_supplier(
        p_supplier_id NUMBER,
        p_sku VARCHAR2,
        p_qty NUMBER,
        p_unit_cost NUMBER
    );

    -- This checks inventory levels but with supplier info.
    -- Duplicates PKG_STORE_OPS.check_reorder_needed but adds supplier logic.
    FUNCTION check_supplier_reorder(p_supplier_id NUMBER) RETURN SYS_REFCURSOR;

END SUPPLIER_PKG;
/

CREATE OR REPLACE PACKAGE BODY SUPPLIER_PKG AS

    PROCEDURE create_supply_order(
        p_supplier_id NUMBER,
        p_store_id NUMBER,
        p_items IN VARCHAR2
    ) IS
        v_order_id NUMBER;
        v_sku VARCHAR2(15);
        v_qty NUMBER;
        v_pos NUMBER := 1;
        v_item_str VARCHAR2(100);
        v_sep_pos NUMBER;
    BEGIN
        SELECT seq_supply_order_id.NEXTVAL INTO v_order_id FROM DUAL;

        INSERT INTO SUPPLY_ORDERS (supply_order_id, supplier_id, store_id)
        VALUES (v_order_id, p_supplier_id, p_store_id);

        -- Parse comma-separated items string: "BEEF-PATTY-4:100;BUN-SESAME:200"
        -- This parsing is fragile. If someone puts a semicolon in a SKU it breaks.
        -- But it was fast to write and the frontend guarantees the format. Sort of.
        WHILE v_pos <= LENGTH(p_items) LOOP
            v_sep_pos := INSTR(p_items, ';', v_pos);
            IF v_sep_pos = 0 THEN v_sep_pos := LENGTH(p_items) + 1; END IF;

            v_item_str := SUBSTR(p_items, v_pos, v_sep_pos - v_pos);
            v_sku := SUBSTR(v_item_str, 1, INSTR(v_item_str, ':') - 1);
            v_qty := TO_NUMBER(SUBSTR(v_item_str, INSTR(v_item_str, ':') + 1));

            INSERT INTO SUPPLY_ORDER_ITEMS (soi_id, supply_order_id, item_sku, quantity, unit_cost)
            VALUES (seq_soi_id.NEXTVAL, v_order_id, v_sku, v_qty, 0);

            v_pos := v_sep_pos + 1;
        END LOOP;

        COMMIT;
    END create_supply_order;

    PROCEDURE receive_supply_order(p_supply_order_id NUMBER) IS
        v_supplier_id NUMBER;
    BEGIN
        SELECT supplier_id INTO v_supplier_id
        FROM SUPPLY_ORDERS WHERE supply_order_id = p_supply_order_id;

        UPDATE SUPPLY_ORDERS SET status = 'RECEIVED', delivery_date = SYSDATE
        WHERE supply_order_id = p_supply_order_id;

        UPDATE SUPPLY_ORDER_ITEMS
        SET received_qty = quantity, received_date = SYSDATE
        WHERE supply_order_id = p_supply_order_id;

        COMMIT;
        -- NOTE: We don't actually update INVENTORY_ITEMS.current_qty here.
        -- That's done separately by receive_inventory_from_supplier.
        -- Yes, it's a two-step process. The store manager has to do both.
        -- We keep reminding them at training. - Anil
    END receive_supply_order;

    PROCEDURE receive_inventory_from_supplier(
        p_supplier_id NUMBER,
        p_sku VARCHAR2,
        p_qty NUMBER,
        p_unit_cost NUMBER
    ) IS
    BEGIN
        -- This does the same thing as PKG_STORE_OPS.update_inventory
        -- but also updates supplier-specific data.
        -- Should've just extended Mike's original proc but we weren't
        -- sure if he'd be OK with us modifying his code.
        UPDATE INVENTORY_ITEMS
        SET current_qty = current_qty + p_qty,
            unit_cost = p_unit_cost,
            supplier_name = (SELECT company_name FROM SUPPLIERS WHERE supplier_id = p_supplier_id)
        WHERE item_sku = p_sku;

        -- We also log to Mike's audit table
        PKG_STORE_OPS.log_audit('INVENTORY_ITEMS', 'RECEIVE', p_sku,
            NULL, 'Received ' || p_qty || ' from supplier ' || p_supplier_id);

        COMMIT;
    END receive_inventory_from_supplier;

    FUNCTION check_supplier_reorder(p_supplier_id NUMBER) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT ii.item_sku, ii.item_name, ii.current_qty, ii.par_level,
                   s.company_name as supplier_name
            FROM INVENTORY_ITEMS ii
            JOIN SUPPLIERS s ON ii.supplier_name = s.company_name
            WHERE s.supplier_id = p_supplier_id
              AND ii.current_qty < ii.par_level;
        RETURN v_cursor;
    END check_supplier_reorder;

END SUPPLIER_PKG;
/
-- ============================================================
-- Online Ordering Tables - 2009
-- Author: Jason Miller (Web Developer)
-- ============================================================
-- I'm a Java/JSF developer, not a DBA. These tables are based
-- on what the web app needs. I'm sure the naming is fine.
-- ============================================================

CREATE TABLE CUSTOMERS (
    cust_id         NUMBER,
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
    online_order_id NUMBER,
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
    oo_item_id      NUMBER,
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
-- ============================================================
-- WEB_ORDER_PKG - Online Order Processing
-- Author: Jason Miller, March 2009
-- ============================================================
-- This handles web orders. It needs to:
-- 1. Accept order from website
-- 2. Create the order record
-- 3. Push it to the store's POS system
-- 4. Update inventory
--
-- For steps 3 and 4, I call Sarah's sp_OrderProcessing procedures
-- and Mike's PKG_STORE_OPS. That way I don't duplicate logic.
-- ============================================================

CREATE OR REPLACE PACKAGE WEB_ORDER_PKG AS

    PROCEDURE place_online_order(
        p_cust_id IN NUMBER,
        p_store_id IN NUMBER,
        p_pickup_time IN DATE,
        p_items IN VARCHAR2,        -- JSON-like: "[{menu_id:1,qty:2},{menu_id:3,qty:1}]"
        p_payment_type IN VARCHAR2,
        p_payment_ref IN VARCHAR2,
        p_order_id OUT NUMBER
    );

    -- Called when the store marks the order as ready
    PROCEDURE mark_order_ready(p_online_order_id NUMBER);

    -- Called when customer picks up
    PROCEDURE complete_pickup(p_online_order_id NUMBER);

    -- Cancel an online order and restock inventory
    PROCEDURE cancel_online_order(p_online_order_id NUMBER);

END WEB_ORDER_PKG;
/

CREATE OR REPLACE PACKAGE BODY WEB_ORDER_PKG AS

    -- Helper to parse Jason's "JSON-like" item format
    -- This is terrible. But JSON libraries weren't in the DB in 2009.
    -- In 2015 someone added APEX_JSON but this still works so nobody changed it.
    FUNCTION parse_order_total(p_items VARCHAR2) RETURN NUMBER IS
        v_total NUMBER(8,2) := 0;
        v_pos NUMBER := 1;
        v_item_str VARCHAR2(200);
        v_menu_id NUMBER;
        v_qty NUMBER;
        v_price NUMBER(6,2);
        v_comma_pos NUMBER;
        v_colon_pos NUMBER;
        v_qty_colon_pos NUMBER;
    BEGIN
        -- Parse format: "[{menu_id:1,qty:2},{menu_id:3,qty:1}]"
        -- Remove brackets
        v_item_str := REPLACE(REPLACE(p_items, '[', ''), ']', '');

        LOOP
            v_comma_pos := INSTR(v_item_str, '},{', v_pos);
            IF v_comma_pos = 0 THEN
                -- Last item
                -- extract menu_id and qty from single {...}
                -- Too complicated to parse properly, approximate for demo
                EXIT;
            END IF;
            v_pos := v_comma_pos + 3;
        END LOOP;

        -- Fallback: just query the most common items
        -- REAL IMPLEMENTATION: This is a stub. The actual parsing happens
        -- in Java before calling this proc. See OrderBean.java.
        -- Jason, 2009
        RETURN 0;  -- Actual total calculated in Java layer
    END parse_order_total;

    PROCEDURE place_online_order(
        p_cust_id IN NUMBER,
        p_store_id IN NUMBER,
        p_pickup_time IN DATE,
        p_items IN VARCHAR2,
        p_payment_type IN VARCHAR2,
        p_payment_ref IN VARCHAR2,
        p_order_id OUT NUMBER
    ) IS
        v_total NUMBER(8,2);
    BEGIN
        SELECT seq_online_order_id.NEXTVAL INTO p_order_id FROM DUAL;

        -- Calculate total (this just returns 0, real calc in Java)
        v_total := parse_order_total(p_items);

        -- Insert the online order
        INSERT INTO ONLINE_ORDERS (online_order_id, cust_id, store_id,
            pickup_time, subtotal, total, payment_type, payment_ref, status)
        VALUES (p_order_id, p_cust_id, p_store_id, p_pickup_time,
            v_total, v_total, p_payment_type, p_payment_ref, 'RECEIVED');

        COMMIT;

        -- ============================================================
        -- NOW PUSH TO THE IN-STORE SYSTEM
        -- ============================================================
        -- We create a corresponding record in Sarah's ORDERS table
        -- so the store's POS screen shows the online order too.
        -- This is the bridge between web and POS.
        DECLARE
            v_pos_order_id NUMBER;
        BEGIN
            sp_create_order(p_store_id, 'TAKEOUT', p_payment_type,
                NULL, v_pos_order_id);

            -- Update the POS order with the online order's amount
            -- We don't use sp_add_order_item here because the web items
            -- are in a different table. We just set the total.
            UPDATE ORDERS SET total_amount = v_total, tax_amount = v_total * 0.07,
                status = 'WEB_ORDER'
            WHERE order_id = v_pos_order_id;
            COMMIT;
        END;

        -- ============================================================
        -- DEDUCT INVENTORY
        -- ============================================================
        -- sp_complete_order handles inventory deduction but it's designed
        -- for in-store orders. For web orders, we need to deduct immediately
        -- (not at pickup time) because the item is reserved.
        --
        -- We call sp_complete_order which internally calls
        -- PKG_STORE_OPS.update_inventory which updates INVENTORY_ITEMS.
        -- This creates a nested call chain:
        -- WEB_ORDER_PKG.place_online_order
        --   -> sp_complete_order
        --     -> PKG_STORE_OPS.update_inventory
        --
        -- Be careful modifying any of these - changing the inventory proc
        -- could break web orders, POS orders, AND supplier receives.
        --
        -- NOTE 2012: Agency team added LOYALTY_PKG.redeem_points which ALSO
        -- calls sp_complete_order. That means redeeming a reward triggers
        -- this entire chain. See loyalty_pkg.sql for that nightmare.
        DECLARE
            v_pos_order_id NUMBER;
        BEGIN
            -- Get the POS order we just created
            SELECT MAX(order_id) INTO v_pos_order_id FROM ORDERS
            WHERE status = 'WEB_ORDER' AND store_id = p_store_id
            ORDER BY order_dt DESC;

            sp_complete_order(v_pos_order_id);
        END;

    END place_online_order;

    PROCEDURE mark_order_ready(p_online_order_id NUMBER) IS
    BEGIN
        UPDATE ONLINE_ORDERS SET status = 'READY' WHERE online_order_id = p_online_order_id;
        COMMIT;
    END mark_order_ready;

    PROCEDURE complete_pickup(p_online_order_id NUMBER) IS
    BEGIN
        UPDATE ONLINE_ORDERS SET status = 'PICKED_UP' WHERE online_order_id = p_online_order_id;
        COMMIT;
    END complete_pickup;

    PROCEDURE cancel_online_order(p_online_order_id NUMBER) IS
    BEGIN
        UPDATE ONLINE_ORDERS SET status = 'CANCELLED' WHERE online_order_id = p_online_order_id;

        -- Restock inventory - call Mike's proc with positive quantity
        -- NOTE: This restocks ALL items from the order as BEEF-PATTY-4
        -- because the inventory deduction in sp_complete_order uses
        -- hardcoded SKU mappings. This is wrong if the order had non-burger items.
        -- TODO: Fix this inventory restock logic - Jason, 2009
        -- TODO: Still need to fix this - Jason, 2010
        -- NOTE: Partially fixed in 2012 loyalty system but only for reward orders.
        --       See LOYALTY_PKG.inventory_for_reward() for the partial fix.
        PKG_STORE_OPS.update_inventory('BEEF-PATTY-4', 1, NULL);

        COMMIT;
    END cancel_online_order;

END WEB_ORDER_PKG;
/
-- ============================================================
-- Customer Management Procedures - 2009
-- Author: Jason Miller
-- ============================================================
-- Basic CRUD for the CUSTOMERS table.
-- I'm using standalone functions like Sarah. Mixing styles, I know.
-- ============================================================

CREATE OR REPLACE PROCEDURE sp_register_customer(
    p_first_name IN VARCHAR2,
    p_last_name IN VARCHAR2,
    p_email IN VARCHAR2,
    p_phone IN VARCHAR2,
    p_password IN VARCHAR2,  -- Already hashed by the Java layer (hopefully)
    p_cust_id OUT NUMBER
) IS
BEGIN
    SELECT seq_cust_id.NEXTVAL INTO p_cust_id FROM DUAL;

    INSERT INTO CUSTOMERS (cust_id, first_name, last_name, email, phone, password_hash)
    VALUES (p_cust_id, p_first_name, p_last_name, p_email, p_phone, p_password);

    COMMIT;
END sp_register_customer;
/

-- Check if email already exists
CREATE OR REPLACE FUNCTION sp_check_email_exists(p_email VARCHAR2) RETURN CHAR IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM CUSTOMERS WHERE email = p_email;
    IF v_count > 0 THEN RETURN 'Y'; ELSE RETURN 'N'; END IF;
END sp_check_email_exists;
/

-- Get customer by email (for login)
CREATE OR REPLACE FUNCTION sp_get_customer_by_email(p_email VARCHAR2) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
BEGIN
    OPEN v_cursor FOR
        SELECT cust_id, first_name, last_name, email, phone, password_hash
        FROM CUSTOMERS
        WHERE email = p_email AND is_active = 'Y';
    RETURN v_cursor;
END sp_get_customer_by_email;
/

-- ============================================================
-- NOTE ADDED 2012:
-- The loyalty team created their own customer lookup in LOYALTY_PKG.
-- They didn't know sp_get_customer_by_email existed.
-- So now there are two completely different ways to look up a customer.
-- This one returns a cursor. Theirs returns a custom type.
-- The web app uses this one. The mobile app uses theirs.
-- Don't merge them, both are in production with different consumers.
-- ============================================================
-- ============================================================
-- Loyalty & Mobile Tables - 2012
-- Agency: TechBridge Solutions (6-month contract)
-- Devs: Dmitri, Alex, Wei - not Oracle specialists
-- ============================================================
-- We built this on a tight timeline. It works.
-- If the schema looks non-standard, that's why.
-- ============================================================

CREATE TABLE LOYALTY_POINTS (
    points_id       NUMBER,
    cust_id         NUMBER NOT NULL,
    points_earned   NUMBER DEFAULT 0,
    points_redeemed NUMBER DEFAULT 0,
    points_balance  NUMBER DEFAULT 0,
    tier            VARCHAR2(20) DEFAULT 'BRONZE',  -- BRONZE, SILVER, GOLD, PLATINUM
    enrolled_date   DATE DEFAULT SYSDATE,
    last_activity   DATE,
    PRIMARY KEY (points_id),
    FOREIGN KEY (cust_id) REFERENCES CUSTOMERS(cust_id)
);

CREATE TABLE REWARDS (
    reward_id       NUMBER,
    reward_name     VARCHAR2(100),
    points_required NUMBER,
    reward_type     VARCHAR2(30),  -- 'FREE_ITEM', 'DISCOUNT', 'UPGRADE'
    menu_item_id    NUMBER,        -- If reward is a free menu item
    discount_pct    NUMBER(5,2),   -- If reward is a discount
    is_active_flg   CHAR(1) DEFAULT 'Y',  -- _flg suffix. Different from everyone else's conventions.
    created_date    DATE DEFAULT SYSDATE,
    PRIMARY KEY (reward_id),
    FOREIGN KEY (menu_item_id) REFERENCES MENU_ITEMS(menu_item_id)
);

CREATE TABLE CUSTOMER_REWARDS (
    redemption_id   NUMBER,
    cust_id         NUMBER NOT NULL,
    reward_id       NUMBER NOT NULL,
    redemption_date DATE DEFAULT SYSDATE,
    order_ref_id    NUMBER,        -- Can reference ORDERS.order_id OR ONLINE_ORDERS.online_order_id
                                   -- No FK because it could reference either table. We handle this in code.
    status          VARCHAR2(20) DEFAULT 'REDEEMED',
    PRIMARY KEY (redemption_id),
    FOREIGN KEY (cust_id) REFERENCES CUSTOMERS(cust_id),
    FOREIGN KEY (reward_id) REFERENCES REWARDS(reward_id)
);

CREATE TABLE MOBILE_SESSIONS (
    session_id      VARCHAR2(64),
    cust_id         NUMBER,
    device_type     VARCHAR2(20),  -- 'IOS', 'ANDROID'
    device_token    VARCHAR2(200),
    login_time      DATE DEFAULT SYSDATE,
    logout_time     DATE,
    ip_address      VARCHAR2(45),  -- IPv6 compatible (Wei insisted)
    is_active       NUMBER(1) DEFAULT 1,  -- Number instead of CHAR. Because Alex was a Java guy.
    PRIMARY KEY (session_id),
    FOREIGN KEY (cust_id) REFERENCES CUSTOMERS(cust_id)
);

CREATE SEQUENCE seq_points_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_reward_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_redemption_id START WITH 1 INCREMENT BY 1;
-- ============================================================
-- LOYALTY_PKG - Loyalty Program Management
-- Agency: TechBridge Solutions
-- Author: Dmitri (Lead), with Alex and Wei
-- Created: January 2012
-- ============================================================
-- This handles the loyalty program. We tried to keep it self-contained
-- but had to call existing procs for orders and inventory.
-- ============================================================

CREATE OR REPLACE PACKAGE LOYALTY_PKG AS

    PROCEDURE enroll_customer(p_cust_id NUMBER);

    PROCEDURE earn_points(p_cust_id NUMBER, p_order_amount NUMBER);

    FUNCTION redeem_points(
        p_cust_id NUMBER,
        p_reward_id NUMBER,
        p_order_id NUMBER,       -- Can be ORDERS.order_id or ONLINE_ORDERS.online_order_id
        p_order_source VARCHAR2  -- 'POS' or 'WEB' - determines which table to look in
    ) RETURN NUMBER;  -- Returns redemption_id

    FUNCTION get_points_balance(p_cust_id NUMBER) RETURN NUMBER;

    -- Wei added this for the mobile app
    PROCEDURE sync_mobile_points(p_cust_id NUMBER, p_device_token VARCHAR2);

    -- Dmitri's optimization: batch process points for all customers
    -- Runs as a nightly job. Takes ~45 minutes for 50K customers.
    PROCEDURE nightly_points_recalc;

    -- Added in 2013 when we needed inventory deduction for reward items
    -- This calls sp_complete_order which calls PKG_STORE_OPS.update_inventory
    -- which is the SAME chain that WEB_ORDER_PKG uses.
    -- Just documenting the chain here so future devs understand the impact
    -- of changing PKG_STORE_OPS.update_inventory:
    --
    -- CALL CHAIN FOR LOYALTY REDEMPTIONS:
    -- LOYALTY_PKG.redeem_points
    --   -> sp_complete_order (Sarah, 2003)
    --     -> PKG_STORE_OPS.update_inventory (Mike, 2000)
    --
    -- CALL CHAIN FOR WEB ORDERS:
    -- WEB_ORDER_PKG.place_online_order (Jason, 2009)
    --   -> sp_complete_order
    --     -> PKG_STORE_OPS.update_inventory
    --
    -- CALL CHAIN FOR IN-STORE ORDERS:
    -- (POS terminal calls sp_complete_order directly)
    --   -> PKG_STORE_OPS.update_inventory
    --
    -- CALL CHAIN FOR SUPPLIER RECEIVING:
    -- SUPPLIER_PKG.receive_inventory_from_supplier (Anil, 2006)
    --   -> PKG_STORE_OPS.update_inventory (only for audit logging)
    --
    -- TL;DR: PKG_STORE_OPS.update_inventory is called by EVERYTHING.
    --        Do not change it without understanding all four call chains.
    PROCEDURE inventory_for_reward(p_reward_id NUMBER, p_qty NUMBER);

END LOYALTY_PKG;
/

CREATE OR REPLACE PACKAGE BODY LOYALTY_PKG AS

    PROCEDURE enroll_customer(p_cust_id NUMBER) IS
    BEGIN
        INSERT INTO LOYALTY_POINTS (points_id, cust_id, points_balance, tier)
        VALUES (seq_points_id.NEXTVAL, p_cust_id, 0, 'BRONZE');
        COMMIT;
    END enroll_customer;

    PROCEDURE earn_points(p_cust_id NUMBER, p_order_amount NUMBER) IS
        v_points NUMBER;
        v_current_tier VARCHAR2(20);
        v_total_points NUMBER;
    BEGIN
        -- 1 point per dollar spent
        v_points := FLOOR(p_order_amount);

        UPDATE LOYALTY_POINTS
        SET points_earned = points_earned + v_points,
            points_balance = points_balance + v_points,
            last_activity = SYSDATE
        WHERE cust_id = p_cust_id;

        -- Check if tier upgrade needed
        SELECT points_balance, tier INTO v_total_points, v_current_tier
        FROM LOYALTY_POINTS WHERE cust_id = p_cust_id;

        -- Tier upgrade logic
        IF v_total_points >= 10000 AND v_current_tier = 'GOLD' THEN
            UPDATE LOYALTY_POINTS SET tier = 'PLATINUM' WHERE cust_id = p_cust_id;
        ELSIF v_total_points >= 5000 AND v_current_tier IN ('SILVER', 'BRONZE') THEN
            UPDATE LOYALTY_POINTS SET tier = 'GOLD' WHERE cust_id = p_cust_id;
        ELSIF v_total_points >= 1000 AND v_current_tier = 'BRONZE' THEN
            UPDATE LOYALTY_POINTS SET tier = 'SILVER' WHERE cust_id = p_cust_id;
        END IF;

        COMMIT;
    END earn_points;

    FUNCTION redeem_points(
        p_cust_id NUMBER,
        p_reward_id NUMBER,
        p_order_id NUMBER,
        p_order_source VARCHAR2
    ) RETURN NUMBER IS
        v_redemption_id NUMBER;
        v_points_needed NUMBER;
        v_current_balance NUMBER;
    BEGIN
        -- Get reward cost
        SELECT points_required INTO v_points_needed FROM REWARDS WHERE reward_id = p_reward_id;

        -- Check balance
        SELECT points_balance INTO v_current_balance
        FROM LOYALTY_POINTS WHERE cust_id = p_cust_id;

        IF v_current_balance < v_points_needed THEN
            RAISE_APPLICATION_ERROR(-20001, 'Insufficient points. Balance: ' || v_current_balance);
        END IF;

        -- Deduct points
        UPDATE LOYALTY_POINTS
        SET points_redeemed = points_redeemed + v_points_needed,
            points_balance = points_balance - v_points_needed,
            last_activity = SYSDATE
        WHERE cust_id = p_cust_id;

        -- Record redemption
        SELECT seq_redemption_id.NEXTVAL INTO v_redemption_id FROM DUAL;
        INSERT INTO CUSTOMER_REWARDS (redemption_id, cust_id, reward_id, order_ref_id)
        VALUES (v_redemption_id, p_cust_id, p_reward_id, p_order_id);

        -- ============================================================
        -- DEDUCT INVENTORY FOR THE REWARD ITEM
        -- ============================================================
        -- The reward could be a free item. If so, we need to deduct it
        -- from inventory. We use the same inventory deduction as in-store
        -- orders, so we call sp_complete_order.
        --
        -- HOWEVER: sp_complete_order uses hardcoded SKU mappings that only
        -- cover menu items 1, 2, 3 (burger, bun, fries). If the reward
        -- is for a different menu item (e.g., a drink, item 6), the inventory
        -- won't be deducted correctly.
        --
        -- This is a known issue. See also: cancel_online_order in WEB_ORDER_PKG
        -- which has the same problem in reverse (restocks wrong items).
        --
        -- Alex: I added the inventory_for_reward proc below to handle this
        -- but it only works for rewards, not the main order flow.
        -- We really need a proper menu-to-SKU mapping table.
        -- Dmitri: No time, contract ends next month. Document it.
        IF p_order_source = 'POS' THEN
            sp_complete_order(p_order_id);
        END IF;

        COMMIT;
        RETURN v_redemption_id;
    END redeem_points;

    FUNCTION get_points_balance(p_cust_id NUMBER) RETURN NUMBER IS
        v_balance NUMBER;
    BEGIN
        SELECT NVL(points_balance, 0) INTO v_balance
        FROM LOYALTY_POINTS WHERE cust_id = p_cust_id;
        RETURN v_balance;
    END get_points_balance;

    PROCEDURE sync_mobile_points(p_cust_id NUMBER, p_device_token VARCHAR2) IS
        v_balance NUMBER;
    BEGIN
        v_balance := get_points_balance(p_cust_id);
        -- In the real app this would push to the mobile device via push notification.
        -- For now we just update the mobile sessions table.
        UPDATE MOBILE_SESSIONS
        SET device_token = p_device_token
        WHERE cust_id = p_cust_id AND is_active = 1;
        COMMIT;
    END sync_mobile_points;

    -- ============================================================
    -- NIGHTLY POINTS RECALC
    -- ============================================================
    -- This recalculates all customer points by scanning all orders.
    -- It runs every night because the real-time points sometimes
    -- get out of sync due to cancelled orders, refunds, etc.
    --
    -- PERFORMANCE NOTE: This does a nested cursor loop over ALL
    -- customers and ALL their orders. With 50,000 customers averaging
    -- 100 orders each, that's 5 million iterations. In nested loops.
    -- It takes 45 minutes. If it fails, it leaves partial data because
    -- the COMMIT is at the end.
    --
    -- Yes, we know this is bad. The alternative was a complex analytic
    -- query that the team wasn't confident writing in Oracle SQL.
    -- The agency contract ended before we could optimize it.
    PROCEDURE nightly_points_recalc IS
        CURSOR c_customers IS
            SELECT cust_id FROM CUSTOMERS WHERE is_active = 'Y';  -- Level 1 cursor

        CURSOR c_orders(p_cust_id NUMBER) IS   -- Level 2 cursor
            SELECT o.order_id, o.total_amount
            FROM ORDERS o
            WHERE o.order_id IN (
                SELECT order_ref_id FROM CUSTOMER_REWARDS WHERE cust_id = p_cust_id
            );

        CURSOR c_online_orders(p_cust_id NUMBER) IS  -- Level 3 cursor (YES, nested inside the loop)
            SELECT oo.online_order_id, oo.total
            FROM ONLINE_ORDERS oo
            WHERE oo.cust_id = p_cust_id
              AND oo.status = 'PICKED_UP';

        v_total_points NUMBER;
        v_points_from_orders NUMBER;
        v_points_from_online NUMBER;
        v_points_redeemed NUMBER;
    BEGIN
        FOR cust_rec IN c_customers LOOP  -- LOOP 1
            v_total_points := 0;
            v_points_from_orders := 0;
            v_points_from_online := 0;
            v_points_redeemed := 0;

            -- Calculate points from in-store orders
            FOR order_rec IN c_orders(cust_rec.cust_id) LOOP  -- LOOP 2
                v_points_from_orders := v_points_from_orders + FLOOR(NVL(order_rec.total_amount, 0));

                -- Also check online orders for this customer
                FOR oo_rec IN c_online_orders(cust_rec.cust_id) LOOP  -- LOOP 3 (nested!)
                    v_points_from_online := v_points_from_online + FLOOR(NVL(oo_rec.total, 0));
                END LOOP;
            END LOOP;

            -- Calculate redeemed points
            SELECT NVL(SUM(r.points_required), 0)
            INTO v_points_redeemed
            FROM CUSTOMER_REWARDS cr
            JOIN REWARDS r ON cr.reward_id = r.reward_id
            WHERE cr.cust_id = cust_rec.cust_id;

            v_total_points := v_points_from_orders + v_points_from_online - v_points_redeemed;

            UPDATE LOYALTY_POINTS
            SET points_earned = v_points_from_orders + v_points_from_online,
                points_redeemed = v_points_redeemed,
                points_balance = GREATEST(v_total_points, 0)
            WHERE cust_id = cust_rec.cust_id;

        END LOOP;

        COMMIT;  -- Single commit at the end. If it fails, everything rolls back.
    END nightly_points_recalc;

    PROCEDURE inventory_for_reward(p_reward_id NUMBER, p_qty NUMBER) IS
        v_menu_item_id NUMBER;
        v_sku VARCHAR2(15);
    BEGIN
        -- Map reward to menu item to SKU
        -- This is a THIRD copy of the menu-to-SKU mapping.
        -- First copy: sp_complete_order (2003)
        -- Second copy: sp_calculate_inventory_usage (2003)
        -- Third copy: here
        -- If a new menu item is added, all three must be updated.
        SELECT menu_item_id INTO v_menu_item_id FROM REWARDS WHERE reward_id = p_reward_id;

        -- Same hardcoded mapping pattern
        IF v_menu_item_id = 1 THEN v_sku := 'BEEF-PATTY-4';
        ELSIF v_menu_item_id = 2 THEN v_sku := 'BUN-SESAME';
        ELSIF v_menu_item_id = 3 THEN v_sku := 'FRIES-CRINKLE';
        ELSIF v_menu_item_id = 6 THEN v_sku := 'SODA-COLA-SYRUP';
        END IF;

        IF v_sku IS NOT NULL THEN
            PKG_STORE_OPS.update_inventory(v_sku, -1 * p_qty, NULL);
        END IF;
    END inventory_for_reward;

END LOYALTY_PKG;
/
-- ============================================================
-- p_MobileOps - Mobile App Support Procedures
-- Author: Wei (TechBridge Solutions)
-- Created: March 2012
-- ============================================================
-- Wei preferred lowercase prefixes and camelCase for procedure names.
-- Different convention from everyone else in the company.
-- The mobile app contractors (different from us) built their backend
-- assuming this naming style. So now we're stuck with it.
-- ============================================================

CREATE OR REPLACE PACKAGE p_MobileOps AS

    PROCEDURE authenticateUser(
        p_email IN VARCHAR2,
        p_password IN VARCHAR2,
        p_session_id OUT VARCHAR2
    );

    PROCEDURE getNearbyStores(
        p_lat IN NUMBER,
        p_lng IN NUMBER,
        p_radius IN NUMBER,  -- miles
        p_results OUT SYS_REFCURSOR
    );

    -- Wei's note: This exists because the mobile app needed a simpler
    -- order placement than Jason's WEB_ORDER_PKG.place_online_order.
    -- That procedure takes a weird JSON-like string. Our mobile app
    -- sends proper JSON. So we built our own.
    -- Yes, there are now TWO ways to place an online order.
    PROCEDURE placeMobileOrder(
        p_cust_id IN NUMBER,
        p_store_id IN NUMBER,
        p_items_json IN VARCHAR2,  -- Proper JSON this time
        p_order_id OUT NUMBER
    );

    -- Get order history for mobile app
    FUNCTION getOrderHistory(
        p_cust_id IN NUMBER,
        p_limit IN NUMBER DEFAULT 20
    ) RETURN SYS_REFCURSOR;

END p_MobileOps;
/

CREATE OR REPLACE PACKAGE BODY p_MobileOps AS

    PROCEDURE authenticateUser(
        p_email IN VARCHAR2,
        p_password IN VARCHAR2,
        p_session_id OUT VARCHAR2
    ) IS
        v_cust_id NUMBER;
        v_stored_hash VARCHAR2(64);
    BEGIN
        -- NOTE: This directly accesses CUSTOMERS table which Jason's
        -- sp_get_customer_by_email also queries. We didn't know about
        -- that procedure when we wrote this. Both work. Both are used.
        SELECT cust_id, password_hash INTO v_cust_id, v_stored_hash
        FROM CUSTOMERS
        WHERE email = p_email AND is_active = 'Y';

        -- Password comparison happens in the app layer.
        -- This just validates that the user exists.
        p_session_id := RAWTOHEX(DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW(v_cust_id || SYSTIMESTAMP, 'AL32UTF8'), 2));

        INSERT INTO MOBILE_SESSIONS (session_id, cust_id, device_type, login_time, ip_address)
        VALUES (p_session_id, v_cust_id, 'UNKNOWN', SYSDATE, '0.0.0.0');

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_session_id := NULL;
        WHEN OTHERS THEN
            -- Swallow other errors. The mobile app retries anyway.
            p_session_id := NULL;
    END authenticateUser;

    PROCEDURE getNearbyStores(
        p_lat IN NUMBER,
        p_lng IN NUMBER,
        p_radius IN NUMBER,
        p_results OUT SYS_REFCURSOR
    ) IS
    BEGIN
        -- In real app this would use spatial queries.
        -- For now, just return all stores. The app filters by distance client-side.
        -- Wei: Oracle Spatial was too complex to set up. The PM said ship it.
        OPEN p_results FOR
            SELECT store_id, store_number, store_name, address_line1, city, state, zip
            FROM STORES
            WHERE is_open = 'Y';
    END getNearbyStores;

    PROCEDURE placeMobileOrder(
        p_cust_id IN NUMBER,
        p_store_id IN NUMBER,
        p_items_json IN VARCHAR2,
        p_order_id OUT NUMBER
    ) IS
    BEGIN
        -- This is essentially a copy of WEB_ORDER_PKG.place_online_order but
        -- with proper JSON handling. We planned to migrate WEB_ORDER_PKG to
        -- use this, but the web team and mobile team had different PMs.
        -- So both exist. Both are in production. Both call sp_complete_order.
        -- Both deduct inventory through PKG_STORE_OPS.update_inventory.

        SELECT seq_online_order_id.NEXTVAL INTO p_order_id FROM DUAL;

        INSERT INTO ONLINE_ORDERS (online_order_id, cust_id, store_id,
            order_type, subtotal, total, payment_type, status)
        VALUES (p_order_id, p_cust_id, p_store_id, 'PICKUP', 0, 0, 'MOBILE', 'RECEIVED');

        -- For inventory deduction, we call the same chain:
        -- p_MobileOps.placeMobileOrder -> sp_complete_order -> PKG_STORE_OPS.update_inventory
        -- But we need a POS order_id for sp_complete_order.
        -- Just use the latest WEB_ORDER in ORDERS table (hack).
        DECLARE
            v_pos_order_id NUMBER;
        BEGIN
            sp_create_order(p_store_id, 'TAKEOUT', 'MOBILE', NULL, v_pos_order_id);

            UPDATE ORDERS SET status = 'MOBILE_ORDER'
            WHERE order_id = v_pos_order_id;

            sp_complete_order(v_pos_order_id);
        END;

        COMMIT;
    END placeMobileOrder;

    FUNCTION getOrderHistory(
        p_cust_id IN NUMBER,
        p_limit IN NUMBER DEFAULT 20
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT * FROM (
                SELECT 'WEB' as source, online_order_id as order_ref, order_date, total, status
                FROM ONLINE_ORDERS WHERE cust_id = p_cust_id
                UNION ALL
                SELECT 'MOBILE', online_order_id, order_date, total, status
                FROM ONLINE_ORDERS WHERE cust_id = p_cust_id AND payment_type = 'MOBILE'
                ORDER BY order_date DESC
            ) WHERE ROWNUM <= p_limit;
        RETURN v_cursor;
    END getOrderHistory;

END p_MobileOps;
/
-- ============================================================
-- RPT_DAILY_SALES_V2_FINAL_USE_THIS - Reporting Package
-- Author: BI Team (Consultants from DataCorp)
-- Created: February 2015
-- ============================================================
-- The original RPT_DAILY_SALES was written in 2013 by an intern.
-- RPT_DAILY_SALES_V2 was a rewrite that was never finished.
-- RPT_DAILY_SALES_V2_FINAL was supposedly the finished version but had bugs.
-- RPT_DAILY_SALES_V2_FINAL_USE_THIS is the one you should actually use. Probably.
--
-- We also generate temp tables because the ORDERS table is too slow
-- to query directly for reports. The temp tables are "refreshed" daily.
-- If a report looks wrong, check if the refresh job ran.
-- ============================================================

CREATE OR REPLACE PACKAGE RPT_DAILY_SALES_V2_FINAL_USE_THIS AS

    -- Main daily sales report
    FUNCTION get_daily_sales(p_date DATE) RETURN SYS_REFCURSOR;

    -- Weekly summary by store
    FUNCTION get_weekly_store_summary(p_start_date DATE) RETURN SYS_REFCURSOR;

    -- Year-over-year comparison
    FUNCTION get_yoy_comparison(p_current_year NUMBER) RETURN SYS_REFCURSOR;

    -- ============================================================
    -- TEMP TABLE REFRESH PROCEDURES
    -- These must be called before running any reports.
    -- The nightly cron job calls these in sequence.
    -- If you run a report without refreshing, the data will be from
    -- whenever the cron last ran (could be days ago if it failed).
    -- ============================================================
    PROCEDURE refresh_sales_temp_table;
    PROCEDURE refresh_inventory_temp_table;
    PROCEDURE refresh_customer_temp_table;

END RPT_DAILY_SALES_V2_FINAL_USE_THIS;
/

CREATE OR REPLACE PACKAGE BODY RPT_DAILY_SALES_V2_FINAL_USE_THIS AS

    -- ============================================================
    -- GLOBAL TEMP TABLES (Created once, data populated by refresh procs)
    -- ============================================================
    -- These used to be actual tables but they bloated the tablespace.
    -- Switched to GTTs. See INCIDENT-4521.

    -- NOTE: The temp table creation scripts are in a separate file
    -- (02_materialized_views.sql). They were put there by accident
    -- because the BI consultant who set them up didn't realize
    -- materialized views and temp tables are different things.
    -- The file name is misleading. Sorry.

    FUNCTION get_daily_sales(p_date DATE) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT s.store_number, s.store_name,
                   COUNT(DISTINCT o.order_id) as order_count,
                   SUM(o.total_amount) as gross_sales,
                   SUM(o.tax_amount) as tax_collected,
                   SUM(o.total_amount) - SUM(o.tax_amount) as net_sales,
                   COUNT(DISTINCT o.employee_id) as unique_cashiers
            FROM ORDERS o
            JOIN STORES s ON o.store_id = s.store_id
            WHERE TRUNC(o.order_dt) = TRUNC(p_date)
              AND o.status IN ('COMPLETED', 'WEB_ORDER', 'MOBILE_ORDER')
            GROUP BY s.store_number, s.store_name
            ORDER BY gross_sales DESC;
        RETURN v_cursor;
    END get_daily_sales;

    FUNCTION get_weekly_store_summary(p_start_date DATE) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT s.store_number, s.store_name,
                   SUM(o.total_amount) as weekly_sales,
                   COUNT(DISTINCT o.order_id) as total_orders,
                   AVG(o.total_amount) as avg_order_value,
                   SUM(CASE WHEN o.order_type = 'DRIVE_THRU' THEN 1 ELSE 0 END) as drive_thru_orders,
                   SUM(CASE WHEN o.payment_method = 'CREDIT' THEN 1 ELSE 0 END) as credit_card_orders
            FROM ORDERS o
            JOIN STORES s ON o.store_id = s.store_id
            WHERE o.order_dt BETWEEN p_start_date AND p_start_date + 7
              AND o.status IN ('COMPLETED', 'WEB_ORDER', 'MOBILE_ORDER')
            GROUP BY s.store_number, s.store_name
            ORDER BY weekly_sales DESC;
        RETURN v_cursor;
    END get_weekly_store_summary;

    FUNCTION get_yoy_comparison(p_current_year NUMBER) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT EXTRACT(MONTH FROM o.order_dt) as month_num,
                   SUM(CASE WHEN EXTRACT(YEAR FROM o.order_dt) = p_current_year
                       THEN o.total_amount ELSE 0 END) as current_year_sales,
                   SUM(CASE WHEN EXTRACT(YEAR FROM o.order_dt) = p_current_year - 1
                       THEN o.total_amount ELSE 0 END) as prev_year_sales
            FROM ORDERS o
            WHERE EXTRACT(YEAR FROM o.order_dt) IN (p_current_year, p_current_year - 1)
              AND o.status IN ('COMPLETED', 'WEB_ORDER', 'MOBILE_ORDER')
            GROUP BY EXTRACT(MONTH FROM o.order_dt)
            ORDER BY month_num;
        RETURN v_cursor;
    END get_yoy_comparison;

    PROCEDURE refresh_sales_temp_table IS
    BEGIN
        -- This procedure used to do: CREATE TABLE TEMP_SALES_SNAPSHOT AS SELECT ... FROM ORDERS
        -- Then the reports would query TEMP_SALES_SNAPSHOT instead of ORDERS directly.
        -- The idea was that ORDERS was too slow for reporting queries (it has no indexes
        -- on order_dt or status columns).
        --
        -- The temp table approach was faster for reports, but the nightly refresh job
        -- sometimes fails silently. When that happens, reports show stale data and
        -- nobody notices until the monthly close.
        --
        -- In 2018, the new CTO tried to replace this with a proper data warehouse.
        -- That project was cancelled after 2 months. We're still using temp tables.
        --
        -- The actual refresh SQL was lost when the DBA server crashed in 2017.
        -- We've been running it from a saved copy in the production DB's job scheduler.
        -- This procedure body is a placeholder - the real code lives in DBMS_SCHEDULER job
        -- "BURGERQUICK_NIGHTLY_REFRESH" on the production server.

        NULL;  -- See DBMS_SCHEDULER for actual implementation
    END refresh_sales_temp_table;

    PROCEDURE refresh_inventory_temp_table IS
    BEGIN
        NULL;  -- See DBMS_SCHEDULER
    END refresh_inventory_temp_table;

    PROCEDURE refresh_customer_temp_table IS
    BEGIN
        NULL;  -- See DBMS_SCHEDULER
    END refresh_customer_temp_table;

END RPT_DAILY_SALES_V2_FINAL_USE_THIS;
/
-- ============================================================
-- Materialized Views (and accidentally, temp table definitions)
-- Author: DataCorp BI Consultants
-- Created: April 2015
-- ============================================================
-- The BI consultant who created this file didn't know the difference
-- between materialized views and global temp tables.
-- So everything is in here. It works. Don't reorganize it.
-- ============================================================

-- Materialized view for monthly store performance
CREATE MATERIALIZED VIEW MV_MONTHLY_STORE_SALES
REFRESH COMPLETE ON DEMAND
AS
SELECT s.store_number, s.store_name, s.state,
       TRUNC(o.order_dt, 'MM') as sale_month,
       COUNT(*) as order_count,
       SUM(o.total_amount) as gross_sales,
       AVG(o.total_amount) as avg_order
FROM ORDERS o
JOIN STORES s ON o.store_id = s.store_id
WHERE o.status IN ('COMPLETED', 'WEB_ORDER', 'MOBILE_ORDER')
GROUP BY s.store_number, s.store_name, s.state, TRUNC(o.order_dt, 'MM');

-- Materialized view for daily inventory levels
-- NEVER REFRESH THIS DURING BUSINESS HOURS. It locks INVENTORY_ITEMS.
-- Only refresh between 2am-4am EST.
CREATE MATERIALIZED VIEW MV_INVENTORY_SNAPSHOT
REFRESH COMPLETE ON DEMAND
AS
SELECT * FROM INVENTORY_ITEMS WHERE is_active = 'Y';

-- Global temp table for report building
-- Yes, this is in the materialized views file. No, I don't know why.
-- It's been here since 2015. Moving it might break the refresh scripts.
CREATE GLOBAL TEMPORARY TABLE TEMP_REPORT_BUILDER (
    row_id          NUMBER,
    store_number    VARCHAR2(5),
    metric_name     VARCHAR2(50),
    metric_value    NUMBER,
    period_start    DATE,
    period_end      DATE
) ON COMMIT PRESERVE ROWS;

-- Another temp table for the nightly customer analytics job
-- The job builds this, runs reports against it, then truncates it.
CREATE GLOBAL TEMPORARY TABLE TEMP_CUSTOMER_SEGMENTS (
    cust_id         NUMBER,
    segment         VARCHAR2(30),  -- 'HIGH_VALUE', 'REGULAR', 'LAPSED', 'NEW'
    total_spent     NUMBER(10,2),
    visit_count     NUMBER,
    last_visit_date DATE,
    avg_order_value NUMBER(8,2)
) ON COMMIT PRESERVE ROWS;

-- ============================================================
-- NOTE: There's an even older materialized view defined in the
-- production DB that doesn't exist in this codebase.
-- MV_LEGACY_DAILY_SALES_PRE_2015 (created 2012, never documented)
-- It's still being refreshed by a cron job nobody knows about.
-- Dropping it might break the CFO's Excel spreadsheet that
-- connects directly to it via ODBC. Leave it alone.
-- ============================================================
-- ============================================================
-- API_ORDER_SERVICE - Modern REST API Wrappers
-- Author: New CTO's team (Kevin, CTO; Marcus, Senior Dev)
-- Created: March 2018
-- ============================================================
-- The CTO wanted to "modernize" by putting REST APIs in front of
-- everything. The idea was:
--   Mobile App -> REST API -> These wrappers -> Old stored procedures
--
-- Phase 1 was wrapping the order flow. Phase 2 was going to be
-- a proper microservice with its own database. Phase 2 never happened.
-- Kevin left in August 2018. Marcus stayed but was reassigned.
-- ============================================================

CREATE OR REPLACE PACKAGE API_ORDER_SERVICE AS

    -- REST-friendly wrappers that call the legacy procedures
    -- Returns JSON-like cursor output for the API layer to serialize

    PROCEDURE api_create_order(
        p_customer_id IN NUMBER,
        p_store_id IN NUMBER,
        p_items_json IN VARCHAR2,    -- Proper JSON now, not Jason's pseudo-JSON
        p_payment_token IN VARCHAR2, -- Stripe token (2018 modernization!)
        p_order_id OUT NUMBER,
        p_status OUT VARCHAR2
    );

    PROCEDURE api_get_order_status(
        p_order_id IN NUMBER,
        p_order_source IN VARCHAR2,  -- 'POS', 'WEB', 'MOBILE'
        p_status OUT VARCHAR2,
        p_details OUT SYS_REFCURSOR
    );

    -- Marcus added this in June 2018: unified order lookup
    -- Doesn't matter if it's POS, web, or mobile - this finds it
    FUNCTION api_find_order(p_order_id NUMBER) RETURN SYS_REFCURSOR;

END API_ORDER_SERVICE;
/

CREATE OR REPLACE PACKAGE BODY API_ORDER_SERVICE AS

    PROCEDURE api_create_order(
        p_customer_id IN NUMBER,
        p_store_id IN NUMBER,
        p_items_json IN VARCHAR2,
        p_payment_token IN VARCHAR2,
        p_order_id OUT NUMBER,
        p_status OUT VARCHAR2
    ) IS
    BEGIN
        -- The CTO wanted this to eventually replace both WEB_ORDER_PKG
        -- and p_MobileOps.placeMobileOrder. Until then, it wraps them.

        -- For now, just delegate to WEB_ORDER_PKG
        -- This means the call chain is now:
        -- API -> API_ORDER_SERVICE.api_create_order
        --        -> WEB_ORDER_PKG.place_online_order
        --           -> sp_complete_order
        --              -> PKG_STORE_OPS.update_inventory
        --
        -- That's 4 levels deep. Marcus documented this in the architecture
        -- wiki (Confluence page "Order Flow Architecture" - last updated 2018).

        WEB_ORDER_PKG.place_online_order(
            p_cust_id => p_customer_id,
            p_store_id => p_store_id,
            p_pickup_time => SYSDATE + INTERVAL '15' MINUTE,
            p_items => p_items_json,  -- Passing JSON to a proc that expects pseudo-JSON. Hope it parses.
            p_payment_type => 'STRIPE',
            p_payment_ref => p_payment_token,
            p_order_id => p_order_id
        );

        p_status := 'SUCCESS';

    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR: ' || SQLERRM;
            -- Swallow the error. The REST endpoint will handle it.
            -- Actually the REST endpoint also swallows errors.
            -- So the mobile app just shows "Order Failed" with no details.
    END api_create_order;

    PROCEDURE api_get_order_status(
        p_order_id IN NUMBER,
        p_order_source IN VARCHAR2,
        p_status OUT VARCHAR2,
        p_details OUT SYS_REFCURSOR
    ) IS
    BEGIN
        IF p_order_source = 'WEB' THEN
            SELECT status INTO p_status FROM ONLINE_ORDERS WHERE online_order_id = p_order_id;
        ELSIF p_order_source = 'POS' THEN
            SELECT status INTO p_status FROM ORDERS WHERE order_id = p_order_id;
        ELSE
            p_status := 'UNKNOWN_SOURCE';
        END IF;

        OPEN p_details FOR SELECT p_order_id as id, p_status as status FROM DUAL;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_status := 'NOT_FOUND';
    END api_get_order_status;

    FUNCTION api_find_order(p_order_id NUMBER) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        -- Try all three order tables. Someone should've built a unified
        -- orders view years ago. See the Confluence page "Unified Order
        -- View Proposal" (draft, created 2015, last edited 2015).
        OPEN v_cursor FOR
            SELECT 'POS' as source, order_id, TO_CHAR(total_amount) as amount, status
            FROM ORDERS WHERE order_id = p_order_id
            UNION ALL
            SELECT 'WEB' as source, online_order_id, TO_CHAR(total) as amount, status
            FROM ONLINE_ORDERS WHERE online_order_id = p_order_id;
        RETURN v_cursor;
    END api_find_order;

END API_ORDER_SERVICE;
/
-- ============================================================
-- USER_SERVICE - Half-Built Microservice Database
-- Author: Marcus (Senior Dev, CTO's modernization team)
-- Started: June 2018 | Abandoned: August 2018
-- ============================================================
-- The CTO's plan was to break the monolith into microservices.
-- This was the "User Service" - it was supposed to own all user/
-- customer/employee data and expose it via REST.
--
-- We got as far as creating the schema before the CTO left.
-- Marcus was reassigned to "more critical work" (pandemic delivery
-- features in 2020 - see 2020_delivery/01_delivery_pkg.sql).
--
-- DO NOT USE THESE TABLES. They are not populated and have no
-- relationship to the actual EMPLOYEES or CUSTOMERS tables.
-- We were supposed to do a data migration from the old tables
-- but never got to it.
-- - Marcus, August 2018
-- ============================================================

-- A clean, normalized user table. The OPPOSITE of everything else.
-- Normal form, proper constraints, UUID primary keys, bcrypt hashes.
-- Completely incompatible with every other table in the database.
CREATE TABLE USERS (
    user_uuid       VARCHAR2(36) PRIMARY KEY,   -- UUID format. NOTHING else uses UUIDs.
    email           VARCHAR2(255) UNIQUE NOT NULL,
    password_hash   VARCHAR2(255) NOT NULL,     -- bcrypt, not SHA-256 like CUSTOMERS
    full_name       VARCHAR2(200) NOT NULL,     -- Single field vs EMPLOYEES/CUSTOMERS first+last
    user_type       VARCHAR2(20) NOT NULL,      -- 'EMPLOYEE', 'CUSTOMER', 'FRANCHISEE'
    phone           VARCHAR2(20),
    is_verified     CHAR(1) DEFAULT 'N',
    is_active       CHAR(1) DEFAULT 'Y',
    created_at      TIMESTAMP DEFAULT SYSTIMESTAMP,  -- TIMESTAMP vs everyone else's DATE
    updated_at      TIMESTAMP,
    deleted_at      TIMESTAMP,                       -- Soft delete. Nobody else does this.
    CONSTRAINT chk_user_type CHECK (user_type IN ('EMPLOYEE', 'CUSTOMER', 'FRANCHISEE'))
);

-- Junction table connecting users to their various roles
-- This was going to replace EMPLOYEES.employee_id, CUSTOMERS.cust_id, etc.
CREATE TABLE USER_ROLES (
    role_id         NUMBER PRIMARY KEY,
    user_uuid       VARCHAR2(36) NOT NULL,
    role_type       VARCHAR2(30) NOT NULL,
    store_id        NUMBER,       -- Nullable - only for employees
    franchise_id    NUMBER,       -- Nullable - only for franchisees
    assigned_at     TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_ur_user FOREIGN KEY (user_uuid) REFERENCES USERS(user_uuid)
);

CREATE SEQUENCE seq_user_role_id START WITH 1 INCREMENT BY 1;

-- ============================================================
-- MIGRATION NOTES (for whoever picks this up):
--
-- To migrate EMPLOYEES -> USERS:
--   SELECT employee_id, first_name || ' ' || last_name, 'EMPLOYEE', phone
--   FROM EMPLOYEES WHERE is_active = 'Y';
--
-- To migrate CUSTOMERS -> USERS:
--   SELECT cust_id, first_name || ' ' || last_name, 'CUSTOMER', phone
--   FROM CUSTOMERS WHERE is_active = 'Y';
--
-- The password hashes are incompatible (SHA-256 vs bcrypt).
-- We'd need a migration script that re-hashes everyone's password.
-- That means forcing all users to reset their password.
-- The PM said "absolutely not" and that's when this project died.
-- ============================================================

-- Stored procedure stub that was never implemented
CREATE OR REPLACE PROCEDURE migrate_users_to_new_schema AS
BEGIN
    -- TODO: Implement migration from EMPLOYEES and CUSTOMERS to USERS
    -- TODO: Handle password re-hashing (SHA-256 -> bcrypt)
    -- TODO: Handle UUID generation for existing users
    -- TODO: Backfill USER_ROLES table
    -- TODO: Update all stored procedures to use user_uuid instead of employee_id/cust_id
    -- TODO: Update all foreign keys in ORDERS, ONLINE_ORDERS, TIME_SHEETS, etc.
    -- TODO: Get sign-off from all 12 teams that depend on these tables
    -- TODO: Schedule downtime (estimated 8 hours for migration)
    -- TODO: Write rollback plan
    --
    -- Estimated effort: 3 months with a team of 4
    -- Actual budget remaining: $0 (CTO's budget was reallocated)
    --
    -- Filed under: "Phase 2 - Q4 2018" (never happened)
    -- Filed under: "Phase 2 - Q2 2019" (never happened)
    -- Not filed anywhere after 2019.

    NULL;
END migrate_users_to_new_schema;
/
-- ============================================================
-- DELIVERY_PKG - Pandemic Delivery Module
-- Author: Emergency SWAT Team (rotating devs, March-May 2020)
-- Primary: Whoever was available that week
-- ============================================================
-- COVID hit. We needed delivery YESTERDAY.
-- No time for design, no code review, just ship it.
--
-- We copied sp_OrderProcessing and WEB_ORDER_PKG patterns and
-- modified them for delivery. Yes, it's mostly copy-paste.
-- Yes, there's duplicate logic. Yes, we know.
--
-- If you're reading this in 2021 or later: I'm sorry.
-- - Dave (contractor, week of March 23, 2020)
-- ============================================================

CREATE TABLE DELIVERY_ORDERS (
    delivery_id     NUMBER PRIMARY KEY,
    online_order_id NUMBER,                     -- Link to ONLINE_ORDERS
    driver_name     VARCHAR2(100),
    driver_phone    VARCHAR2(20),
    delivery_addr   VARCHAR2(200),
    delivery_city   VARCHAR2(50),
    delivery_state  VARCHAR2(2),
    delivery_zip    VARCHAR2(10),
    pickup_time     DATE,                       -- When driver picked up from store
    estimated_delivery DATE,
    actual_delivery DATE,
    delivery_fee    NUMBER(5,2) DEFAULT 3.99,
    tip             NUMBER(5,2),
    status          VARCHAR2(20) DEFAULT 'ASSIGNED',
    -- ASSIGNED -> PICKED_UP -> EN_ROUTE -> DELIVERED / FAILED
    notes           VARCHAR2(500),
    created_dt      DATE DEFAULT SYSDATE
);

CREATE TABLE DELIVERY_DRIVERS (
    driver_id       NUMBER PRIMARY KEY,
    first_name      VARCHAR2(50),
    last_name       VARCHAR2(50),
    phone           VARCHAR2(20),
    vehicle_type    VARCHAR2(30),
    vehicle_plate   VARCHAR2(20),
    is_active_flg   CHAR(1) DEFAULT 'Y',        -- _flg like the loyalty team
    hired_dt        DATE DEFAULT SYSDATE,
    rating          NUMBER(2,1) DEFAULT 5.0
);

CREATE SEQUENCE seq_delivery_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_driver_id START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PACKAGE DELIVERY_PKG AS

    -- This is basically a copy of WEB_ORDER_PKG.place_online_order
    -- but with delivery fields. See that procedure for the original.
    PROCEDURE create_delivery(
        p_online_order_id IN NUMBER,
        p_delivery_addr IN VARCHAR2,
        p_delivery_city IN VARCHAR2,
        p_delivery_state IN VARCHAR2,
        p_delivery_zip IN VARCHAR2,
        p_delivery_id OUT NUMBER
    );

    -- Assign a driver. Copy of the employee assignment pattern from 2003.
    PROCEDURE assign_driver(p_delivery_id NUMBER, p_driver_id NUMBER);

    -- Update delivery status. Very similar to sp_complete_order status update.
    PROCEDURE update_delivery_status(p_delivery_id NUMBER, p_status VARCHAR2);

    -- Calculate delivery fee. Duplicates sp_get_order_total logic.
    -- We needed delivery fee calculation added to the order total.
    -- sp_get_order_total doesn't include delivery fees because delivery
    -- didn't exist when Sarah wrote it in 2003.
    FUNCTION calculate_delivery_total(p_delivery_id NUMBER) RETURN NUMBER;

    -- ============================================================
    -- COPY-PASTED INVENTORY DEDUCTION FOR DELIVERY
    -- ============================================================
    -- This is essentially sp_complete_order but for delivery orders.
    -- We couldn't reuse sp_complete_order directly because it only
    -- works with ORDERS table, not DELIVERY_ORDERS.
    --
    -- Could've added a parameter to sp_complete_order. But:
    -- 1. Sarah doesn't work here anymore (left 2010)
    -- 2. Nobody feels confident modifying sp_complete_order
    -- 3. It's called by 6+ other procedures
    -- 4. We're in a pandemic and have 3 days to ship this
    --
    -- So we copied the logic. It diverges from the original now.
    -- Changes to sp_complete_order's inventory logic will NOT be
    -- reflected here. Keep both in sync manually.
    PROCEDURE deduct_inventory_for_delivery(p_delivery_id NUMBER);

END DELIVERY_PKG;
/

CREATE OR REPLACE PACKAGE BODY DELIVERY_PKG AS

    PROCEDURE create_delivery(
        p_online_order_id IN NUMBER,
        p_delivery_addr IN VARCHAR2,
        p_delivery_city IN VARCHAR2,
        p_delivery_state IN VARCHAR2,
        p_delivery_zip IN VARCHAR2,
        p_delivery_id OUT NUMBER
    ) IS
    BEGIN
        SELECT seq_delivery_id.NEXTVAL INTO p_delivery_id FROM DUAL;

        INSERT INTO DELIVERY_ORDERS (delivery_id, online_order_id,
            delivery_addr, delivery_city, delivery_state, delivery_zip,
            estimated_delivery, status)
        VALUES (p_delivery_id, p_online_order_id,
            p_delivery_addr, p_delivery_city, p_delivery_state, p_delivery_zip,
            SYSDATE + INTERVAL '30' MINUTE, 'ASSIGNED');

        -- Also update the online order to indicate delivery
        UPDATE ONLINE_ORDERS
        SET order_type = 'DELIVERY'
        WHERE online_order_id = p_online_order_id;

        COMMIT;
    END create_delivery;

    PROCEDURE assign_driver(p_delivery_id NUMBER, p_driver_id NUMBER) IS
    BEGIN
        UPDATE DELIVERY_ORDERS
        SET driver_name = (SELECT first_name || ' ' || last_name FROM DELIVERY_DRIVERS WHERE driver_id = p_driver_id),
            driver_phone = (SELECT phone FROM DELIVERY_DRIVERS WHERE driver_id = p_driver_id)
        WHERE delivery_id = p_delivery_id;
        COMMIT;
    END assign_driver;

    PROCEDURE update_delivery_status(p_delivery_id NUMBER, p_status VARCHAR2) IS
    BEGIN
        IF p_status = 'PICKED_UP' THEN
            UPDATE DELIVERY_ORDERS SET status = 'PICKED_UP', pickup_time = SYSDATE
            WHERE delivery_id = p_delivery_id;
        ELSIF p_status = 'EN_ROUTE' THEN
            UPDATE DELIVERY_ORDERS SET status = 'EN_ROUTE' WHERE delivery_id = p_delivery_id;
        ELSIF p_status = 'DELIVERED' THEN
            UPDATE DELIVERY_ORDERS SET status = 'DELIVERED', actual_delivery = SYSDATE
            WHERE delivery_id = p_delivery_id;

            -- When delivered, update the online order too
            UPDATE ONLINE_ORDERS
            SET status = 'DELIVERED'
            WHERE online_order_id = (SELECT online_order_id FROM DELIVERY_ORDERS WHERE delivery_id = p_delivery_id);

        ELSIF p_status = 'FAILED' THEN
            UPDATE DELIVERY_ORDERS SET status = 'FAILED' WHERE delivery_id = p_delivery_id;
        END IF;
        COMMIT;
    END update_delivery_status;

    FUNCTION calculate_delivery_total(p_delivery_id NUMBER) RETURN NUMBER IS
        v_order_total NUMBER(8,2);
        v_delivery_fee NUMBER(5,2);
        v_tip NUMBER(5,2);
        v_online_order_id NUMBER;
    BEGIN
        SELECT online_order_id INTO v_online_order_id
        FROM DELIVERY_ORDERS WHERE delivery_id = p_delivery_id;

        -- Get original order total using Sarah's function
        -- Wait, sp_get_order_total works on ORDERS table, not ONLINE_ORDERS.
        -- The online order has its total in ONLINE_ORDERS.total.
        -- But ONLINE_ORDERS.total was set to 0 (it was calculated in Java).
        -- So we use sp_get_order_total on the POS order linked to this web order.
        -- No wait, sp_get_order_total uses ORDER_ITEMS, not ONLINE_ORDER_ITEMS.
        -- Different tables. Different columns. Same logic though.
        -- You know what, just read from ONLINE_ORDERS directly:
        SELECT NVL(total, 0) INTO v_order_total
        FROM ONLINE_ORDERS
        WHERE online_order_id = v_online_order_id;

        SELECT NVL(delivery_fee, 0), NVL(tip, 0)
        INTO v_delivery_fee, v_tip
        FROM DELIVERY_ORDERS
        WHERE delivery_id = p_delivery_id;

        RETURN v_order_total + v_delivery_fee + v_tip;
    END calculate_delivery_total;

    PROCEDURE deduct_inventory_for_delivery(p_delivery_id NUMBER) IS
        v_online_order_id NUMBER;
    BEGIN
        SELECT online_order_id INTO v_online_order_id
        FROM DELIVERY_ORDERS WHERE delivery_id = p_delivery_id;

        -- This is where we would deduct inventory for the delivery order.
        -- It's essentially the same logic as sp_complete_order.
        -- But since delivery happens AFTER the web order, inventory was already
        -- deducted when the web order was placed (see WEB_ORDER_PKG.place_online_order
        -- which calls sp_complete_order).
        --
        -- So this is redundant for items, but NOT redundant for new delivery-specific
        -- items like delivery bags, stickers, etc. that we track separately.
        --
        -- TODO: Add inventory items for delivery supplies - Dave, March 2020
        -- TODO: Still waiting on the SKU numbers for delivery supplies - Dave, April 2020
        -- Dave's contract ended. Someone else needs to follow up.
        --
        -- For now, NO-OP.
        NULL;
    END deduct_inventory_for_delivery;

END DELIVERY_PKG;
/
-- ============================================================
-- BurgerQuick Systems - Known Issues & Tech Debt Register
-- Last Updated: March 2023
-- Maintained by: Whoever drew the short straw this sprint
-- ============================================================

-- ============================================================
-- INVENTORY OF ALL STORED PROCEDURES (as far as we know)
-- ============================================================
-- PACKAGE/PROCEDURE              | AUTHOR  | YEAR | STATUS
-- -------------------------------+---------+------+----------
-- PKG_STORE_OPS (v3)             | Mike    | 2000 | ACTIVE - Emp+Store+Inventory CRUD. Everything depends on this
-- sp_create_order                | Sarah   | 2003 | ACTIVE - POS still uses directly
-- sp_add_order_item              | Sarah   | 2003 | ACTIVE
-- sp_complete_order              | Sarah   | 2003 | ACTIVE - Called by 6+ other procs
-- sp_get_order_total             | Sarah   | 2003 | ACTIVE - Only used by 1 report
-- sp_calculate_inventory_usage   | Sarah   | 2003 | UNKNOWN - May be dead code
-- sp_log_hours                   | Sarah   | 2003 | ACTIVE
-- sp_calculate_payroll           | Sarah   | 2003 | ACTIVE - But payroll moving to ADP in 2024
-- FRANCHISE_PKG (updated 2025)   | Raj     | 2006 | ACTIVE - Full CRUD added in 2025
-- SUPPLIER_PKG                   | Anil    | 2006 | ACTIVE
-- sp_register_customer           | Jason   | 2009 | ACTIVE - Web registration
-- sp_check_email_exists          | Jason   | 2009 | ACTIVE
-- sp_get_customer_by_email       | Jason   | 2009 | ACTIVE - Web login
-- WEB_ORDER_PKG                  | Jason   | 2009 | ACTIVE - Web ordering
-- LOYALTY_PKG                    | Dmitri  | 2012 | ACTIVE - But buggy (see issues below)
-- p_MobileOps                    | Wei     | 2012 | ACTIVE - Mobile app
-- RPT_DAILY_SALES_V2_FINAL_...   | BI Team | 2015 | ACTIVE - Reports run on this
-- API_ORDER_SERVICE              | Marcus  | 2018 | SEMI-ACTIVE - Only mobile uses REST
-- DELIVERY_PKG                   | Various | 2020 | ACTIVE - Delivery is 30% of orders now
-- migrate_users_to_new_schema    | Marcus  | 2018 | DEAD - Never implemented
-- USERS table                    | Marcus  | 2018 | DEAD - Never populated
-- TEMP_FRANCHISE_OWNER_LINK      | Anil    | 2006 | DEAD - Junction table never finished
-- MV_LEGACY_DAILY_SALES_PRE_2015 | Unknown | 2012 | DEAD? - Exists in prod, not in code

-- ============================================================
-- KNOWN CALL CHAINS (how deep does the nesting go?)
-- ============================================================
-- 1. API Order:
--    API_ORDER_SERVICE.api_create_order
--      -> WEB_ORDER_PKG.place_online_order
--        -> sp_create_order (Sarah)
--        -> sp_complete_order (Sarah)
--          -> PKG_STORE_OPS.update_inventory (Mike)
--
-- 2. In-Store Order:
--    POS -> sp_create_order -> sp_add_order_item -> sp_complete_order
--      -> PKG_STORE_OPS.update_inventory
--
-- 3. Loyalty Redemption:
--    LOYALTY_PKG.redeem_points
--      -> sp_complete_order
--        -> PKG_STORE_OPS.update_inventory
--
-- 4. Mobile Order:
--    p_MobileOps.placeMobileOrder
--      -> sp_create_order
--      -> sp_complete_order
--        -> PKG_STORE_OPS.update_inventory
--
-- 5. Delivery (inventory already deducted by web order flow):
--    DELIVERY_PKG.create_delivery
--      -> (no inventory call - already done by WEB_ORDER_PKG)
--
-- OBSERVATION: Everything flows into PKG_STORE_OPS.update_inventory.
--              If that procedure breaks, EVERYTHING breaks.

-- ============================================================
-- KNOWN BUGS & ISSUES
-- ============================================================
-- 1. Menu-to-SKU mapping is hardcoded in 3 different places:
--    - sp_complete_order (2003)
--    - sp_calculate_inventory_usage (2003)
--    - LOYALTY_PKG.inventory_for_reward (2012)
--    Adding a new menu item requires updating all three.
--    Adding a new SKU-to-menu mapping requires updating all three.
--    Nobody has done this consistently. Some menu items don't deduct inventory.

-- 2. Customer lookup is duplicated:
--    - sp_get_customer_by_email returns a cursor
--    - p_MobileOps.authenticateUser does direct table access
--    - LOYALTY_PKG.enroll_customer accesses CUSTOMERS directly
--    No single source of truth for customer data.

-- 3. Order totals are calculated differently in different places:
--    - sp_get_order_total: pre-tax subtotal
--    - FRANCHISE_PKG.calculate_franchise_order_total: includes tax
--    - WEB_ORDER_PKG.parse_order_total: returns 0 (calculated in Java)
--    - DELIVERY_PKG.calculate_delivery_total: includes delivery fee + tip

-- 4. nightly_points_recalc takes 45 minutes and blocks other processes.
--    If it fails, all customer loyalty points are wrong until the next run.

-- 5. cancel_online_order restocks inventory as BEEF-PATTY-4 regardless
--    of what was actually ordered. Known since 2009. Never fixed.

-- 6. FRANCHISE_OWNER_LINK junction table was created but never used.
--    Owner data is duplicated between FRANCHISES and FRANCHISE_OWNERS.

-- 7. The USERS migration project (2018) was abandoned. The tables exist
--    but are empty. A new developer might think they're the canonical
--    user tables and try to use them.

-- 8. Naming conventions across the codebase:
--    - is_active (Mike, 2000)
--    - _yn suffix (Sarah, 2003)
--    - _flg suffix (Loyalty team, 2012)
--    - is_active_flg (Delivery team, 2020 - combined two conventions!)
--    All mean the same thing. Good luck.

-- ============================================================
-- THINGS NOBODY DARES TO CHANGE
-- ============================================================
-- - PKG_STORE_OPS.update_inventory: called by everything
-- - ORDERS table structure: POS depends on exact column order
-- - MV_LEGACY_DAILY_SALES_PRE_2015: CFO's spreadsheet depends on it
-- - sp_complete_order: hardcoded SKU mappings, known buggy, still critical
-- - The nightly refresh job: undocumented, fragile, essential


-- ============================================================
-- Inventory Delivery Enhancement - 2026
-- ============================================================
-- New delivery tracking for inventory supply shipments
-- to stores. Separate from the 2020 DELIVERY_PKG (food delivery).
-- Uses Oracle Advanced Queues for guaranteed message passing
-- between delivery creation and fulfillment.
-- ============================================================

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE INVENTORY_DELIVERIES (
    delivery_id             NUMBER PRIMARY KEY,
    destination_store_id    NUMBER NOT NULL,
    delivery_address        VARCHAR2(200),
    requested_date          DATE,
    notes                   VARCHAR2(500),
    status                  VARCHAR2(20) DEFAULT 'PENDING',
    aq_msg_id               RAW(16),
    fulfilled_date          DATE,
    fulfilled_by            VARCHAR2(30),
    created_date            DATE DEFAULT SYSDATE,
    created_by              VARCHAR2(30) DEFAULT USER,
    CONSTRAINT fk_idel_store FOREIGN KEY (destination_store_id)
        REFERENCES STORES(store_id)
);

CREATE TABLE INVENTORY_DELIVERY_ITEMS (
    line_item_id    NUMBER PRIMARY KEY,
    delivery_id     NUMBER NOT NULL,
    item_sku        VARCHAR2(15) NOT NULL,
    quantity        NUMBER(8,2) NOT NULL,
    unit_cost       NUMBER(8,4),
    created_date    DATE DEFAULT SYSDATE,
    CONSTRAINT fk_idelitem_delivery FOREIGN KEY (delivery_id)
        REFERENCES INVENTORY_DELIVERIES(delivery_id) ON DELETE CASCADE,
    CONSTRAINT fk_idelitem_sku FOREIGN KEY (item_sku)
        REFERENCES INVENTORY_ITEMS(item_sku)
);

-- ============================================================
-- SEQUENCES
-- ============================================================

CREATE SEQUENCE seq_inv_delivery_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_inv_delivery_item_id START WITH 1 INCREMENT BY 1;

-- ============================================================
-- ORACLE ADVANCED QUEUES
-- ============================================================

-- Payload object type: what gets carried in each queue message
CREATE OR REPLACE TYPE inv_delivery_payload AS OBJECT (
    delivery_id             NUMBER,
    destination_store_id    NUMBER,
    created_date            DATE,
    status_at_enqueue       VARCHAR2(20)
);
/

-- Queue table and queue
BEGIN
    DBMS_AQADM.CREATE_QUEUE_TABLE(
        queue_table        => 'inv_delivery_queue_tbl',
        queue_payload_type => 'inv_delivery_payload',
        sort_list          => 'ENQ_TIME',
        multiple_consumers => FALSE,
        comment            => 'BurgerQuick Inventory Delivery Queue - FIFO ordered'
    );

    DBMS_AQADM.CREATE_QUEUE(
        queue_name  => 'inv_delivery_queue',
        queue_table => 'inv_delivery_queue_tbl',
        comment     => 'Queue for inventory delivery processing'
    );

    DBMS_AQADM.START_QUEUE(
        queue_name => 'inv_delivery_queue'
    );
END;
/

-- Grants for the application schema user
-- Run as DBA or schema owner with grant privileges
GRANT EXECUTE ON inv_delivery_payload TO system;
BEGIN
    DBMS_AQADM.GRANT_QUEUE_PRIVILEGE(
        privilege     => 'ENQUEUE',
        queue_name    => 'inv_delivery_queue',
        grantee       => 'system',
        grant_option  => FALSE
    );
    DBMS_AQADM.GRANT_QUEUE_PRIVILEGE(
        privilege     => 'DEQUEUE',
        queue_name    => 'inv_delivery_queue',
        grantee       => 'system',
        grant_option  => FALSE
    );
END;
/

-- ============================================================
-- DELIVERY_ENHANCEMENT_PKG - Inventory Delivery Processing
-- Author: BurgerQuick Systems, 2026
-- ============================================================
-- Handles inventory supply deliveries to stores.
-- Uses Oracle AQ (inv_delivery_queue) to bridge creation
-- and fulfillment flows.
--
-- Does NOT replace DELIVERY_PKG (2020) — that handles
-- food delivery to customers. This handles inventory
-- supply delivery to stores. Different domains.
-- ============================================================

CREATE OR REPLACE PACKAGE DELIVERY_ENHANCEMENT_PKG AS

    PROCEDURE create_inventory_delivery(
        p_destination_store_id IN NUMBER,
        p_delivery_address     IN VARCHAR2,
        p_requested_date       IN VARCHAR2,
        p_notes                IN VARCHAR2,
        p_items                IN VARCHAR2,
        p_delivery_id          OUT NUMBER
    );

    FUNCTION get_active_inventory_items RETURN SYS_REFCURSOR;

    FUNCTION get_all_stores RETURN SYS_REFCURSOR;

    FUNCTION get_pending_deliveries RETURN SYS_REFCURSOR;

    FUNCTION get_delivery_items(p_delivery_id NUMBER) RETURN SYS_REFCURSOR;

    PROCEDURE fulfill_inventory_delivery(
        p_delivery_id  IN NUMBER,
        p_fulfilled_by IN VARCHAR2
    );

    PROCEDURE cancel_inventory_delivery(
        p_delivery_id IN NUMBER,
        p_reason      IN VARCHAR2
    );

END DELIVERY_ENHANCEMENT_PKG;
/





CREATE OR REPLACE PACKAGE BODY DELIVERY_ENHANCEMENT_PKG AS

    -------------------------------------------------------------------
    -- Helper: parse next "SKU:QTY" from semicolon-delimited string
    -------------------------------------------------------------------
    PROCEDURE parse_next_item(
        p_items_str IN OUT VARCHAR2,
        p_sku       OUT VARCHAR2,
        p_qty       OUT NUMBER
    ) IS
        v_semi  NUMBER;
        v_colon NUMBER;
        v_item  VARCHAR2(100);
    BEGIN
        p_sku := NULL;
        p_qty := NULL;
        IF p_items_str IS NULL OR LENGTH(TRIM(p_items_str)) = 0 THEN
            RETURN;
        END IF;
        v_semi := INSTR(p_items_str, ';');
        IF v_semi = 0 THEN
            v_item := p_items_str;
            p_items_str := NULL;
        ELSE
            v_item := SUBSTR(p_items_str, 1, v_semi - 1);
            p_items_str := SUBSTR(p_items_str, v_semi + 1);
        END IF;
        v_colon := INSTR(v_item, ':');
        IF v_colon > 0 THEN
            p_sku := SUBSTR(v_item, 1, v_colon - 1);
            p_qty := TO_NUMBER(SUBSTR(v_item, v_colon + 1));
        END IF;
    END parse_next_item;

    -------------------------------------------------------------------
    -- CREATE DELIVERY
    -------------------------------------------------------------------
    PROCEDURE create_inventory_delivery(
        p_destination_store_id IN NUMBER,
        p_delivery_address     IN VARCHAR2,
        p_requested_date       IN VARCHAR2,
        p_notes                IN VARCHAR2,
        p_items                IN VARCHAR2,
        p_delivery_id          OUT NUMBER
    ) IS
        v_items_str VARCHAR2(4000);
        v_sku       VARCHAR2(15);
        v_qty       NUMBER(8,2);
        v_line_id   NUMBER;
        v_req_date  DATE;
        v_msg_id    RAW(16);
    BEGIN
        SELECT seq_inv_delivery_id.NEXTVAL INTO p_delivery_id FROM DUAL;

        IF p_requested_date IS NOT NULL
           AND LENGTH(TRIM(p_requested_date)) > 0 THEN
            v_req_date := TO_DATE(TRIM(p_requested_date), 'YYYY-MM-DD');
        END IF;

        INSERT INTO INVENTORY_DELIVERIES (
            delivery_id, destination_store_id, delivery_address,
            requested_date, notes, status, created_date, created_by
        ) VALUES (
            p_delivery_id, p_destination_store_id, p_delivery_address,
            v_req_date, p_notes,
            'PENDING', SYSDATE, USER
        );

        -- Parse items
        v_items_str := p_items;
        LOOP
            parse_next_item(v_items_str, v_sku, v_qty);
            EXIT WHEN v_sku IS NULL OR v_qty IS NULL;
            SELECT seq_inv_delivery_item_id.NEXTVAL INTO v_line_id FROM DUAL;
            INSERT INTO INVENTORY_DELIVERY_ITEMS (
                line_item_id, delivery_id, item_sku, quantity, created_date
            ) VALUES (
                v_line_id, p_delivery_id, v_sku, v_qty, SYSDATE
            );
        END LOOP;

        -- AQ enqueue via dynamic SQL — no compile-time dependency on DBMS_AQ
        BEGIN
            EXECUTE IMMEDIATE '
                DECLARE
                    v_opts  DBMS_AQ.ENQUEUE_OPTIONS_T;
                    v_props DBMS_AQ.MESSAGE_PROPERTIES_T;
                    v_pld   inv_delivery_payload;
                    v_mid   RAW(16);
                BEGIN
                    v_pld := inv_delivery_payload(:did, :sid, SYSDATE, ''PENDING'');
                    DBMS_AQ.ENQUEUE(
                        queue_name         => ''inv_delivery_queue'',
                        enqueue_options    => v_opts,
                        message_properties => v_props,
                        payload            => v_pld,
                        msgid              => v_mid
                    );
                    :msg := v_mid;
                END;'
                USING IN p_delivery_id, IN p_destination_store_id, OUT v_msg_id;
        EXCEPTION
            WHEN OTHERS THEN
                v_msg_id := NULL;
        END;

        IF v_msg_id IS NOT NULL THEN
            UPDATE INVENTORY_DELIVERIES
            SET aq_msg_id = v_msg_id
            WHERE delivery_id = p_delivery_id;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END create_inventory_delivery;

    -------------------------------------------------------------------
    -- DROPDOWN CURSORS
    -------------------------------------------------------------------
    FUNCTION get_active_inventory_items RETURN SYS_REFCURSOR IS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT item_sku, item_name, unit_type, current_qty
            FROM INVENTORY_ITEMS
            WHERE is_active = 'Y'
            ORDER BY item_name;
        RETURN v_cur;
    END;

    FUNCTION get_all_stores RETURN SYS_REFCURSOR IS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT store_id, store_number, store_name, city, state
            FROM STORES
            WHERE is_open = 'Y'
            ORDER BY store_number;
        RETURN v_cur;
    END;

    -------------------------------------------------------------------
    -- QUEUE DATA
    -------------------------------------------------------------------
    FUNCTION get_pending_deliveries RETURN SYS_REFCURSOR IS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT d.delivery_id,
                   d.destination_store_id,
                   d.delivery_address,
                   d.requested_date,
                   d.notes,
                   d.status,
                   d.created_date,
                   d.created_by,
                   s.store_number,
                   s.store_name,
                   (SELECT COUNT(*)
                    FROM INVENTORY_DELIVERY_ITEMS idi
                    WHERE idi.delivery_id = d.delivery_id) AS item_count
            FROM INVENTORY_DELIVERIES d
            JOIN STORES s ON d.destination_store_id = s.store_id
            WHERE d.status = 'PENDING'
            ORDER BY d.delivery_id ASC;
        RETURN v_cur;
    END;

    FUNCTION get_delivery_items(p_delivery_id NUMBER) RETURN SYS_REFCURSOR IS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT idi.line_item_id,
                   idi.item_sku,
                   idi.quantity,
                   idi.unit_cost,
                   ii.item_name,
                   ii.unit_type,
                   ii.current_qty AS current_inventory_qty
            FROM INVENTORY_DELIVERY_ITEMS idi
            JOIN INVENTORY_ITEMS ii ON idi.item_sku = ii.item_sku
            WHERE idi.delivery_id = p_delivery_id
            ORDER BY idi.line_item_id;
        RETURN v_cur;
    END;

    -------------------------------------------------------------------
    -- FULFILL
    -------------------------------------------------------------------
    PROCEDURE fulfill_inventory_delivery(
        p_delivery_id  IN NUMBER,
        p_fulfilled_by IN VARCHAR2
    ) IS
        v_msg_id RAW(16);
        v_current_status VARCHAR2(20);
        resource_busy EXCEPTION;
        PRAGMA EXCEPTION_INIT(resource_busy, -54);
    BEGIN
        BEGIN
            SELECT status INTO v_current_status
            FROM INVENTORY_DELIVERIES
            WHERE delivery_id = p_delivery_id
            FOR UPDATE NOWAIT;
        EXCEPTION
            WHEN resource_busy THEN
                RAISE_APPLICATION_ERROR(-20002, 'This delivery is currently locked by another transaction.');
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003, 'Delivery with ID ' || p_delivery_id || ' does not exist.');
        END;

        IF v_current_status != 'PENDING' THEN
            RAISE_APPLICATION_ERROR(-20001, 'Delivery has already been fulfilled, is processing, or was cancelled.');
        END IF;

        UPDATE INVENTORY_DELIVERIES
        SET status = 'PROCESSING'
        WHERE delivery_id = p_delivery_id;

        FOR rec IN (
            SELECT item_sku, quantity
            FROM INVENTORY_DELIVERY_ITEMS
            WHERE delivery_id = p_delivery_id
        ) LOOP
            PKG_STORE_OPS.update_inventory(
                p_sku             => rec.item_sku,
                p_quantity_change => rec.quantity,
                p_store_no        => NULL
            );
        END LOOP;

        UPDATE INVENTORY_DELIVERIES
        SET status = 'COMPLETED',
            fulfilled_date = SYSDATE,
            fulfilled_by = p_fulfilled_by
        WHERE delivery_id = p_delivery_id;

        -- Dequeue AQ message via dynamic SQL
        SELECT aq_msg_id INTO v_msg_id
        FROM INVENTORY_DELIVERIES
        WHERE delivery_id = p_delivery_id;

        IF v_msg_id IS NOT NULL THEN
            BEGIN
                EXECUTE IMMEDIATE '
                    DECLARE
                        v_opts  DBMS_AQ.DEQUEUE_OPTIONS_T;
                        v_props DBMS_AQ.MESSAGE_PROPERTIES_T;
                        v_pld   inv_delivery_payload;
                        v_mid   RAW(16);
                    BEGIN
                        v_opts.msgid     := :m;
                        v_opts.wait      := DBMS_AQ.NO_WAIT;
                        v_opts.navigation := DBMS_AQ.FIRST_MESSAGE;
                        DBMS_AQ.DEQUEUE(
                            queue_name         => ''inv_delivery_queue'',
                            dequeue_options    => v_opts,
                            message_properties => v_props,
                            payload            => v_pld,
                            msgid              => v_mid
                        );
                    END;'
                    USING IN v_msg_id;
            EXCEPTION
                WHEN OTHERS THEN NULL;
            END;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            PKG_STORE_OPS.log_audit(
                'INVENTORY_DELIVERIES', 'FULFILL_E',
                TO_CHAR(p_delivery_id), NULL, SQLERRM
            );
            ROLLBACK;
            RAISE;
    END fulfill_inventory_delivery;

    -------------------------------------------------------------------
    -- CANCEL
    -------------------------------------------------------------------
    PROCEDURE cancel_inventory_delivery(
        p_delivery_id IN NUMBER,
        p_reason      IN VARCHAR2
    ) IS
        v_current_status VARCHAR2(20);
        v_notes VARCHAR2(500);
        resource_busy EXCEPTION;
        PRAGMA EXCEPTION_INIT(resource_busy, -54);
    BEGIN
        BEGIN
            SELECT status INTO v_current_status
            FROM INVENTORY_DELIVERIES
            WHERE delivery_id = p_delivery_id
            FOR UPDATE NOWAIT;
        EXCEPTION
            WHEN resource_busy THEN
                RAISE_APPLICATION_ERROR(-20002, 'This delivery is currently locked by another operation.');
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003, 'Delivery with ID ' || p_delivery_id || ' does not exist.');
        END;

        IF v_current_status != 'PENDING' THEN
            RAISE_APPLICATION_ERROR(-20001, 'Only PENDING deliveries can be cancelled.');
        END IF;

        IF p_reason IS NOT NULL THEN
            SELECT notes INTO v_notes
            FROM INVENTORY_DELIVERIES
            WHERE delivery_id = p_delivery_id;
            UPDATE INVENTORY_DELIVERIES
            SET status = 'CANCELLED',
                notes = v_notes || ' [CANCELLED: ' || p_reason || ']'
            WHERE delivery_id = p_delivery_id;
        ELSE
            UPDATE INVENTORY_DELIVERIES
            SET status = 'CANCELLED'
            WHERE delivery_id = p_delivery_id;
        END IF;
        COMMIT;
    END cancel_inventory_delivery;

END DELIVERY_ENHANCEMENT_PKG;
/
