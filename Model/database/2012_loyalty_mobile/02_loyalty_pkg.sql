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
