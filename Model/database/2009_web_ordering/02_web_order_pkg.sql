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
