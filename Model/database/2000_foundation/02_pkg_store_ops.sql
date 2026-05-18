-- ============================================================
-- PKG_STORE_OPS - Core Store Operations Package
-- Author: Mike Henderson, March 2000
-- ============================================================
-- This is THE package for all store operations.
-- I've kept everything in one package so it's easy to find.
-- If you need to add something, add it here. Don't create new packages.
-- - Mike
-- ============================================================

CREATE OR REPLACE PACKAGE PKG_STORE_OPS AS

    -- Employee functions
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
    PROCEDURE fire_employee(p_emp_id VARCHAR2);  -- Mike's naming: direct!

    -- Inventory functions
    FUNCTION get_inventory_status(p_store_no VARCHAR2) RETURN SYS_REFCURSOR;
    PROCEDURE update_inventory(
        p_sku VARCHAR2,
        p_quantity_change NUMBER,  -- negative for deduction
        p_store_no VARCHAR2
    );
    FUNCTION check_reorder_needed(p_sku VARCHAR2) RETURN CHAR;  -- Returns Y/N

    -- General
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

    FUNCTION get_next_employee_id RETURN VARCHAR2 IS
        v_count NUMBER;
        v_new_id VARCHAR2(10);
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
            SELECT employee_id, first_name, last_name, position, hourly_rate
            FROM EMPLOYEES
            WHERE store_number = p_store_no AND is_active = 'Y';
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
        v_new_id VARCHAR2(10);
    BEGIN
        v_new_id := get_next_employee_id();
        INSERT INTO EMPLOYEES (employee_id, first_name, last_name, ssn, store_number, position, hourly_rate)
        VALUES (v_new_id, p_first_name, p_last_name, p_ssn, p_store_number, p_position, p_hourly_rate);
        log_audit('EMPLOYEES', 'INSERT', v_new_id, NULL, p_first_name || ' ' || p_last_name);
        COMMIT;
    END;

    PROCEDURE fire_employee(p_emp_id VARCHAR2) IS
    BEGIN
        UPDATE EMPLOYEES SET is_active = 'N' WHERE employee_id = p_emp_id;
        log_audit('EMPLOYEES', 'TERMINATE', p_emp_id, 'Active', 'Inactive');
        COMMIT;
    END;

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

END PKG_STORE_OPS;
/
