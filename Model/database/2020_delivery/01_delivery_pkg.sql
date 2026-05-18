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
