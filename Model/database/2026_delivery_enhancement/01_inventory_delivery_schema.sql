-- ============================================================
-- Inventory Delivery Enhancement - 2026
-- Tables, Sequences, Oracle AQ Setup
-- ============================================================
-- New delivery tracking for inventory supply shipments
-- to stores. Separate from the 2020 DELIVERY_PKG (food delivery).
-- Uses Oracle Advanced Queues for guaranteed message passing
-- between delivery creation and fulfillment.
-- ============================================================

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE INVENTORY_DELIVERIES (
    delivery_id             NUMBER PRIMARY KEY,
    destination_store_id    NUMBER NOT NULL,
    delivery_address        VARCHAR2(200),
    requested_date          DATE,
    notes                   VARCHAR2(500),
    status                  VARCHAR2(20) DEFAULT 'PENDING',
    aq_msg_id               RAW(16),
    fulfilled_date          DATE,
    fulfilled_by            VARCHAR2(30),
    created_date            DATE DEFAULT SYSDATE,
    created_by              VARCHAR2(30) DEFAULT USER,
    CONSTRAINT fk_idel_store FOREIGN KEY (destination_store_id)
        REFERENCES STORES(store_id)
);

CREATE TABLE INVENTORY_DELIVERY_ITEMS (
    line_item_id    NUMBER PRIMARY KEY,
    delivery_id     NUMBER NOT NULL,
    item_sku        VARCHAR2(15) NOT NULL,
    quantity        NUMBER(8,2) NOT NULL,
    unit_cost       NUMBER(8,4),
    created_date    DATE DEFAULT SYSDATE,
    CONSTRAINT fk_idelitem_delivery FOREIGN KEY (delivery_id)
        REFERENCES INVENTORY_DELIVERIES(delivery_id) ON DELETE CASCADE,
    CONSTRAINT fk_idelitem_sku FOREIGN KEY (item_sku)
        REFERENCES INVENTORY_ITEMS(item_sku)
);

-- ============================================================
-- SEQUENCES
-- ============================================================

CREATE SEQUENCE seq_inv_delivery_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_inv_delivery_item_id START WITH 1 INCREMENT BY 1;

-- ============================================================
-- ORACLE ADVANCED QUEUES
-- ============================================================

-- Payload object type: what gets carried in each queue message
CREATE OR REPLACE TYPE inv_delivery_payload AS OBJECT (
    delivery_id             NUMBER,
    destination_store_id    NUMBER,
    created_date            DATE,
    status_at_enqueue       VARCHAR2(20)
);
/

-- Queue table and queue
BEGIN
    DBMS_AQADM.CREATE_QUEUE_TABLE(
        queue_table        => 'inv_delivery_queue_tbl',
        queue_payload_type => 'inv_delivery_payload',
        sort_list          => 'ENQ_TIME',
        multiple_consumers => FALSE,
        comment            => 'BurgerQuick Inventory Delivery Queue - FIFO ordered'
    );

    DBMS_AQADM.CREATE_QUEUE(
        queue_name  => 'inv_delivery_queue',
        queue_table => 'inv_delivery_queue_tbl',
        comment     => 'Queue for inventory delivery processing'
    );

    DBMS_AQADM.START_QUEUE(
        queue_name => 'inv_delivery_queue'
    );
END;
/

-- Grants for the application schema user
-- Run as DBA or schema owner with grant privileges
GRANT EXECUTE ON inv_delivery_payload TO system;
BEGIN
    DBMS_AQADM.GRANT_QUEUE_PRIVILEGE(
        privilege     => 'ENQUEUE',
        queue_name    => 'inv_delivery_queue',
        grantee       => 'system',
        grant_option  => FALSE
    );
    DBMS_AQADM.GRANT_QUEUE_PRIVILEGE(
        privilege     => 'DEQUEUE',
        queue_name    => 'inv_delivery_queue',
        grantee       => 'system',
        grant_option  => FALSE
    );
END;
/
