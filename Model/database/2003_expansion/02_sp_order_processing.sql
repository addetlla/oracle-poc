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
