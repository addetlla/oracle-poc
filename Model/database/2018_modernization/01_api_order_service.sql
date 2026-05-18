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
