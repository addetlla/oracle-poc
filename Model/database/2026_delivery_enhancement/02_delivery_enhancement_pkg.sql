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

        -- Pub/Sub enqueue onto inv_broadcast_queue via dynamic SQL
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
                        queue_name         => ''inv_broadcast_queue'',
                        enqueue_options    => v_opts,
                        message_properties => v_props,
                        payload            => v_pld,
                        msgid              => v_mid
                    );
                END;'
                USING IN p_delivery_id, IN p_destination_store_id;
        EXCEPTION
            WHEN OTHERS THEN
                PKG_STORE_OPS.log_audit('inv_broadcast_queue', 'ENQUEUE_E', TO_CHAR(p_delivery_id), NULL, SQLERRM);
        END;

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

        -- Pub/Sub enqueue 'COMPLETED' event onto inv_broadcast_queue via dynamic SQL
        DECLARE
            v_store_id NUMBER;
        BEGIN
            SELECT destination_store_id INTO v_store_id
            FROM INVENTORY_DELIVERIES
            WHERE delivery_id = p_delivery_id;

            EXECUTE IMMEDIATE '
                DECLARE
                    v_opts  DBMS_AQ.ENQUEUE_OPTIONS_T;
                    v_props DBMS_AQ.MESSAGE_PROPERTIES_T;
                    v_pld   inv_delivery_payload;
                    v_mid   RAW(16);
                BEGIN
                    v_pld := inv_delivery_payload(:did, :sid, SYSDATE, ''COMPLETED'');
                    DBMS_AQ.ENQUEUE(
                        queue_name         => ''inv_broadcast_queue'',
                        enqueue_options    => v_opts,
                        message_properties => v_props,
                        payload            => v_pld,
                        msgid              => v_mid
                    );
                END;'
                USING IN p_delivery_id, IN v_store_id;
        EXCEPTION
            WHEN OTHERS THEN
                PKG_STORE_OPS.log_audit('inv_broadcast_queue', 'ENQUEUE_F_E', TO_CHAR(p_delivery_id), NULL, SQLERRM);
        END;

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

        -- Pub/Sub enqueue 'CANCELLED' event onto inv_broadcast_queue via dynamic SQL
        DECLARE
            v_store_id NUMBER;
        BEGIN
            SELECT destination_store_id INTO v_store_id
            FROM INVENTORY_DELIVERIES
            WHERE delivery_id = p_delivery_id;

            EXECUTE IMMEDIATE '
                DECLARE
                    v_opts  DBMS_AQ.ENQUEUE_OPTIONS_T;
                    v_props DBMS_AQ.MESSAGE_PROPERTIES_T;
                    v_pld   inv_delivery_payload;
                    v_mid   RAW(16);
                BEGIN
                    v_pld := inv_delivery_payload(:did, :sid, SYSDATE, ''CANCELLED'');
                    DBMS_AQ.ENQUEUE(
                        queue_name         => ''inv_broadcast_queue'',
                        enqueue_options    => v_opts,
                        message_properties => v_props,
                        payload            => v_pld,
                        msgid              => v_mid
                    );
                END;'
                USING IN p_delivery_id, IN v_store_id;
        EXCEPTION
            WHEN OTHERS THEN
                PKG_STORE_OPS.log_audit('inv_broadcast_queue', 'ENQUEUE_C_E', TO_CHAR(p_delivery_id), NULL, SQLERRM);
        END;

        COMMIT;
    END cancel_inventory_delivery;

END DELIVERY_ENHANCEMENT_PKG;
/
