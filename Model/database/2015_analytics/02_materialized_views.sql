-- ============================================================
-- Materialized Views (and accidentally, temp table definitions)
-- Author: DataCorp BI Consultants
-- Created: April 2015
-- ============================================================
-- The BI consultant who created this file didn't know the difference
-- between materialized views and global temp tables.
-- So everything is in here. It works. Don't reorganize it.
-- ============================================================

-- Materialized view for monthly store performance
CREATE MATERIALIZED VIEW MV_MONTHLY_STORE_SALES
REFRESH COMPLETE ON DEMAND
AS
SELECT s.store_number, s.store_name, s.state,
       TRUNC(o.order_dt, 'MM') as sale_month,
       COUNT(*) as order_count,
       SUM(o.total_amount) as gross_sales,
       AVG(o.total_amount) as avg_order
FROM ORDERS o
JOIN STORES s ON o.store_id = s.store_id
WHERE o.status IN ('COMPLETED', 'WEB_ORDER', 'MOBILE_ORDER')
GROUP BY s.store_number, s.store_name, s.state, TRUNC(o.order_dt, 'MM');

-- Materialized view for daily inventory levels
-- NEVER REFRESH THIS DURING BUSINESS HOURS. It locks INVENTORY_ITEMS.
-- Only refresh between 2am-4am EST.
CREATE MATERIALIZED VIEW MV_INVENTORY_SNAPSHOT
REFRESH COMPLETE ON DEMAND
AS
SELECT * FROM INVENTORY_ITEMS WHERE is_active = 'Y';

-- Global temp table for report building
-- Yes, this is in the materialized views file. No, I don't know why.
-- It's been here since 2015. Moving it might break the refresh scripts.
CREATE GLOBAL TEMPORARY TABLE TEMP_REPORT_BUILDER (
    row_id          NUMBER,
    store_number    VARCHAR2(5),
    metric_name     VARCHAR2(50),
    metric_value    NUMBER,
    period_start    DATE,
    period_end      DATE
) ON COMMIT PRESERVE ROWS;

-- Another temp table for the nightly customer analytics job
-- The job builds this, runs reports against it, then truncates it.
CREATE GLOBAL TEMPORARY TABLE TEMP_CUSTOMER_SEGMENTS (
    cust_id         NUMBER,
    segment         VARCHAR2(30),  -- 'HIGH_VALUE', 'REGULAR', 'LAPSED', 'NEW'
    total_spent     NUMBER(10,2),
    visit_count     NUMBER,
    last_visit_date DATE,
    avg_order_value NUMBER(8,2)
) ON COMMIT PRESERVE ROWS;

-- ============================================================
-- NOTE: There's an even older materialized view defined in the
-- production DB that doesn't exist in this codebase.
-- MV_LEGACY_DAILY_SALES_PRE_2015 (created 2012, never documented)
-- It's still being refreshed by a cron job nobody knows about.
-- Dropping it might break the CFO's Excel spreadsheet that
-- connects directly to it via ODBC. Leave it alone.
-- ============================================================
