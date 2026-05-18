-- ============================================================
-- Loyalty & Mobile Tables - 2012
-- Agency: TechBridge Solutions (6-month contract)
-- Devs: Dmitri, Alex, Wei - not Oracle specialists
-- ============================================================
-- We built this on a tight timeline. It works.
-- If the schema looks non-standard, that's why.
-- ============================================================

CREATE TABLE LOYALTY_POINTS (
    points_id       NUMBER,
    cust_id         NUMBER NOT NULL,
    points_earned   NUMBER DEFAULT 0,
    points_redeemed NUMBER DEFAULT 0,
    points_balance  NUMBER DEFAULT 0,
    tier            VARCHAR2(20) DEFAULT 'BRONZE',  -- BRONZE, SILVER, GOLD, PLATINUM
    enrolled_date   DATE DEFAULT SYSDATE,
    last_activity   DATE,
    PRIMARY KEY (points_id),
    FOREIGN KEY (cust_id) REFERENCES CUSTOMERS(cust_id)
);

CREATE TABLE REWARDS (
    reward_id       NUMBER,
    reward_name     VARCHAR2(100),
    points_required NUMBER,
    reward_type     VARCHAR2(30),  -- 'FREE_ITEM', 'DISCOUNT', 'UPGRADE'
    menu_item_id    NUMBER,        -- If reward is a free menu item
    discount_pct    NUMBER(5,2),   -- If reward is a discount
    is_active_flg   CHAR(1) DEFAULT 'Y',  -- _flg suffix. Different from everyone else's conventions.
    created_date    DATE DEFAULT SYSDATE,
    PRIMARY KEY (reward_id),
    FOREIGN KEY (menu_item_id) REFERENCES MENU_ITEMS(menu_item_id)
);

CREATE TABLE CUSTOMER_REWARDS (
    redemption_id   NUMBER,
    cust_id         NUMBER NOT NULL,
    reward_id       NUMBER NOT NULL,
    redemption_date DATE DEFAULT SYSDATE,
    order_ref_id    NUMBER,        -- Can reference ORDERS.order_id OR ONLINE_ORDERS.online_order_id
                                   -- No FK because it could reference either table. We handle this in code.
    status          VARCHAR2(20) DEFAULT 'REDEEMED',
    PRIMARY KEY (redemption_id),
    FOREIGN KEY (cust_id) REFERENCES CUSTOMERS(cust_id),
    FOREIGN KEY (reward_id) REFERENCES REWARDS(reward_id)
);

CREATE TABLE MOBILE_SESSIONS (
    session_id      VARCHAR2(64),
    cust_id         NUMBER,
    device_type     VARCHAR2(20),  -- 'IOS', 'ANDROID'
    device_token    VARCHAR2(200),
    login_time      DATE DEFAULT SYSDATE,
    logout_time     DATE,
    ip_address      VARCHAR2(45),  -- IPv6 compatible (Wei insisted)
    is_active       NUMBER(1) DEFAULT 1,  -- Number instead of CHAR. Because Alex was a Java guy.
    PRIMARY KEY (session_id),
    FOREIGN KEY (cust_id) REFERENCES CUSTOMERS(cust_id)
);

CREATE SEQUENCE seq_points_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_reward_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_redemption_id START WITH 1 INCREMENT BY 1;
