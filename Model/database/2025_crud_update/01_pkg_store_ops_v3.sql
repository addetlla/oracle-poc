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
