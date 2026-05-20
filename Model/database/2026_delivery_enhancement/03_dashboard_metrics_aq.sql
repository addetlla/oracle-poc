-- ============================================================
-- 03_dashboard_metrics_aq.sql
-- Setting up real-time analytics using Multi-Consumer Oracle AQ
-- and PL/SQL Asynchronous Callbacks.
-- ============================================================

-- 1. Create Dashboard Stats Table to hold pre-aggregated counts
DECLARE
    v_cnt NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_cnt FROM user_tables WHERE table_name = 'DASHBOARD_STATS';
    IF v_cnt = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE DASHBOARD_STATS (
                stat_name   VARCHAR2(50) PRIMARY KEY,
                stat_value  NUMBER DEFAULT 0
            )';
    END IF;
END;
/

-- 2. Seed Initial Stats & Sync with Existing Deliveries
DELETE FROM DASHBOARD_STATS;
INSERT INTO DASHBOARD_STATS (stat_name, stat_value) 
VALUES ('PENDING_DELIVERIES', (SELECT COUNT(*) FROM INVENTORY_DELIVERIES WHERE status = 'PENDING'));
INSERT INTO DASHBOARD_STATS (stat_name, stat_value) 
VALUES ('DELIVERED_TODAY', (SELECT COUNT(*) FROM INVENTORY_DELIVERIES WHERE status = 'COMPLETED' AND TRUNC(fulfilled_date) = TRUNC(SYSDATE)));
COMMIT;

-- 3. Clean up existing objects if they exist
DECLARE
    v_cnt NUMBER;
BEGIN
    -- Stop queue if exists
    BEGIN
        DBMS_AQADM.STOP_QUEUE(queue_name => 'inv_broadcast_queue');
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    -- Drop queue if exists
    BEGIN
        DBMS_AQADM.DROP_QUEUE(queue_name => 'inv_broadcast_queue');
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    -- Drop queue table if exists
    SELECT COUNT(*) INTO v_cnt FROM user_tables WHERE table_name = 'INV_BROADCAST_QTABLE';
    IF v_cnt > 0 THEN
        DBMS_AQADM.DROP_QUEUE_TABLE(queue_table => 'inv_broadcast_qtable');
    END IF;
END;
/

-- 4. Create Multi-Consumer Queue Table & Queue
BEGIN
    DBMS_AQADM.CREATE_QUEUE_TABLE(
        queue_table        => 'inv_broadcast_qtable',
        queue_payload_type => 'inv_delivery_payload',
        multiple_consumers => TRUE,
        comment            => 'Multi-consumer broadcast queue for delivery analytics'
    );

    DBMS_AQADM.CREATE_QUEUE(
        queue_name  => 'inv_broadcast_queue',
        queue_table => 'inv_broadcast_qtable'
    );

    DBMS_AQADM.START_QUEUE(
        queue_name => 'inv_broadcast_queue'
    );
END;
/

-- 5. Add Subscribers to the Queue
DECLARE
    v_sub SYS.AQ$_AGENT;
BEGIN
    -- Subscriber 1: Core Operations (Fulfillment)
    v_sub := SYS.AQ$_AGENT('DELIVERY_FULFILLMENT_AGENT', NULL, NULL);
    DBMS_AQADM.ADD_SUBSCRIBER('inv_broadcast_queue', v_sub);

    -- Subscriber 2: Real-time Analytics (Dashboard Metrics)
    v_sub := SYS.AQ$_AGENT('DASHBOARD_METRICS_AGENT', NULL, NULL);
    DBMS_AQADM.ADD_SUBSCRIBER('inv_broadcast_queue', v_sub);
END;
/

-- 6. Create the Asynchronous Event Callback Procedure
CREATE OR REPLACE PROCEDURE sync_dashboard_metrics_callback(
    context  IN RAW,
    reginfo  IN SYS.AQ$_REG_INFO,
    descr    IN SYS.AQ$_DESCRIPTOR,
    payload  IN RAW,
    payloadl IN NUMBER
) IS
    v_opts   DBMS_AQ.DEQUEUE_OPTIONS_T;
    v_props  DBMS_AQ.MESSAGE_PROPERTIES_T;
    v_pld    inv_delivery_payload;
    v_mid    RAW(16);
BEGIN
    -- Configure dequeue specifically for the DASHBOARD_METRICS_AGENT subscriber
    v_opts.consumer_name := 'DASHBOARD_METRICS_AGENT';
    v_opts.msgid         := descr.msg_id;
    v_opts.wait          := DBMS_AQ.NO_WAIT;
    
    DBMS_AQ.DEQUEUE(
        queue_name         => descr.queue_name,
        dequeue_options    => v_opts,
        message_properties => v_props,
        payload            => v_pld,
        msgid              => v_mid
    );

    -- Instantly and asynchronously adjust the metrics counters
    IF v_pld.status_at_enqueue = 'PENDING' THEN
        UPDATE DASHBOARD_STATS
        SET stat_value = stat_value + 1
        WHERE stat_name = 'PENDING_DELIVERIES';
    ELSIF v_pld.status_at_enqueue = 'COMPLETED' THEN
        UPDATE DASHBOARD_STATS
        SET stat_value = stat_value - 1
        WHERE stat_name = 'PENDING_DELIVERIES';

        UPDATE DASHBOARD_STATS
        SET stat_value = stat_value + 1
        WHERE stat_name = 'DELIVERED_TODAY';
    ELSIF v_pld.status_at_enqueue = 'CANCELLED' THEN
        UPDATE DASHBOARD_STATS
        SET stat_value = stat_value - 1
        WHERE stat_name = 'PENDING_DELIVERIES';
    END IF;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        PKG_STORE_OPS.log_audit('AQ_DASHBOARD_CB', 'ERROR', TO_CHAR(v_pld.delivery_id), NULL, SQLERRM);
        ROLLBACK;
END;
/

-- 7. Register the Callback Procedure with Oracle AQ
-- We listen for messages bound for DASHBOARD_METRICS_AGENT on inv_broadcast_queue
BEGIN
    -- Clean up previous registrations if any
    BEGIN
        DBMS_AQ.UNREGISTER(
            sys.aq$_reg_info_list(
                sys.aq$_reg_info(
                    'inv_broadcast_queue:DASHBOARD_METRICS_AGENT',
                    DBMS_AQ.NAMESPACE_ANONYMOUS,
                    'plsql://sync_dashboard_metrics_callback',
                    HEXTORAW('00')
                )
            ),
            1
        );
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- Register new callback
    DBMS_AQ.REGISTER(
        sys.aq$_reg_info_list(
            sys.aq$_reg_info(
                'inv_broadcast_queue:DASHBOARD_METRICS_AGENT',
                DBMS_AQ.NAMESPACE_ANONYMOUS,
                'plsql://sync_dashboard_metrics_callback',
                HEXTORAW('00')
            )
        ),
        1
    );
END;
/

-- 8. Enable system enqueue and dequeue grants for system schema
BEGIN
    DBMS_AQADM.GRANT_QUEUE_PRIVILEGE('ENQUEUE', 'inv_broadcast_queue', 'system', FALSE);
    DBMS_AQADM.GRANT_QUEUE_PRIVILEGE('DEQUEUE', 'inv_broadcast_queue', 'system', FALSE);
END;
/
