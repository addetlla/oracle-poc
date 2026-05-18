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
