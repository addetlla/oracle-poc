-- ============================================================
-- RPT_DAILY_SALES_V2_FINAL_USE_THIS - Reporting Package
-- Author: BI Team (Consultants from DataCorp)
-- Created: February 2015
-- ============================================================
-- The original RPT_DAILY_SALES was written in 2013 by an intern.
-- RPT_DAILY_SALES_V2 was a rewrite that was never finished.
-- RPT_DAILY_SALES_V2_FINAL was supposedly the finished version but had bugs.
-- RPT_DAILY_SALES_V2_FINAL_USE_THIS is the one you should actually use. Probably.
--
-- We also generate temp tables because the ORDERS table is too slow
-- to query directly for reports. The temp tables are "refreshed" daily.
-- If a report looks wrong, check if the refresh job ran.
-- ============================================================

CREATE OR REPLACE PACKAGE RPT_DAILY_SALES_V2_FINAL_USE_THIS AS

    -- Main daily sales report
    FUNCTION get_daily_sales(p_date DATE) RETURN SYS_REFCURSOR;

    -- Weekly summary by store
    FUNCTION get_weekly_store_summary(p_start_date DATE) RETURN SYS_REFCURSOR;

    -- Year-over-year comparison
    FUNCTION get_yoy_comparison(p_current_year NUMBER) RETURN SYS_REFCURSOR;

    -- ============================================================
    -- TEMP TABLE REFRESH PROCEDURES
    -- These must be called before running any reports.
    -- The nightly cron job calls these in sequence.
    -- If you run a report without refreshing, the data will be from
    -- whenever the cron last ran (could be days ago if it failed).
    -- ============================================================
    PROCEDURE refresh_sales_temp_table;
    PROCEDURE refresh_inventory_temp_table;
    PROCEDURE refresh_customer_temp_table;

END RPT_DAILY_SALES_V2_FINAL_USE_THIS;
/

CREATE OR REPLACE PACKAGE BODY RPT_DAILY_SALES_V2_FINAL_USE_THIS AS

    -- ============================================================
    -- GLOBAL TEMP TABLES (Created once, data populated by refresh procs)
    -- ============================================================
    -- These used to be actual tables but they bloated the tablespace.
    -- Switched to GTTs. See INCIDENT-4521.

    -- NOTE: The temp table creation scripts are in a separate file
    -- (02_materialized_views.sql). They were put there by accident
    -- because the BI consultant who set them up didn't realize
    -- materialized views and temp tables are different things.
    -- The file name is misleading. Sorry.

    FUNCTION get_daily_sales(p_date DATE) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT s.store_number, s.store_name,
                   COUNT(DISTINCT o.order_id) as order_count,
                   SUM(o.total_amount) as gross_sales,
                   SUM(o.tax_amount) as tax_collected,
                   SUM(o.total_amount) - SUM(o.tax_amount) as net_sales,
                   COUNT(DISTINCT o.employee_id) as unique_cashiers
            FROM ORDERS o
            JOIN STORES s ON o.store_id = s.store_id
            WHERE TRUNC(o.order_dt) = TRUNC(p_date)
              AND o.status IN ('COMPLETED', 'WEB_ORDER', 'MOBILE_ORDER')
            GROUP BY s.store_number, s.store_name
            ORDER BY gross_sales DESC;
        RETURN v_cursor;
    END get_daily_sales;

    FUNCTION get_weekly_store_summary(p_start_date DATE) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT s.store_number, s.store_name,
                   SUM(o.total_amount) as weekly_sales,
                   COUNT(DISTINCT o.order_id) as total_orders,
                   AVG(o.total_amount) as avg_order_value,
                   SUM(CASE WHEN o.order_type = 'DRIVE_THRU' THEN 1 ELSE 0 END) as drive_thru_orders,
                   SUM(CASE WHEN o.payment_method = 'CREDIT' THEN 1 ELSE 0 END) as credit_card_orders
            FROM ORDERS o
            JOIN STORES s ON o.store_id = s.store_id
            WHERE o.order_dt BETWEEN p_start_date AND p_start_date + 7
              AND o.status IN ('COMPLETED', 'WEB_ORDER', 'MOBILE_ORDER')
            GROUP BY s.store_number, s.store_name
            ORDER BY weekly_sales DESC;
        RETURN v_cursor;
    END get_weekly_store_summary;

    FUNCTION get_yoy_comparison(p_current_year NUMBER) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT EXTRACT(MONTH FROM o.order_dt) as month_num,
                   SUM(CASE WHEN EXTRACT(YEAR FROM o.order_dt) = p_current_year
                       THEN o.total_amount ELSE 0 END) as current_year_sales,
                   SUM(CASE WHEN EXTRACT(YEAR FROM o.order_dt) = p_current_year - 1
                       THEN o.total_amount ELSE 0 END) as prev_year_sales
            FROM ORDERS o
            WHERE EXTRACT(YEAR FROM o.order_dt) IN (p_current_year, p_current_year - 1)
              AND o.status IN ('COMPLETED', 'WEB_ORDER', 'MOBILE_ORDER')
            GROUP BY EXTRACT(MONTH FROM o.order_dt)
            ORDER BY month_num;
        RETURN v_cursor;
    END get_yoy_comparison;

    PROCEDURE refresh_sales_temp_table IS
    BEGIN
        -- This procedure used to do: CREATE TABLE TEMP_SALES_SNAPSHOT AS SELECT ... FROM ORDERS
        -- Then the reports would query TEMP_SALES_SNAPSHOT instead of ORDERS directly.
        -- The idea was that ORDERS was too slow for reporting queries (it has no indexes
        -- on order_dt or status columns).
        --
        -- The temp table approach was faster for reports, but the nightly refresh job
        -- sometimes fails silently. When that happens, reports show stale data and
        -- nobody notices until the monthly close.
        --
        -- In 2018, the new CTO tried to replace this with a proper data warehouse.
        -- That project was cancelled after 2 months. We're still using temp tables.
        --
        -- The actual refresh SQL was lost when the DBA server crashed in 2017.
        -- We've been running it from a saved copy in the production DB's job scheduler.
        -- This procedure body is a placeholder - the real code lives in DBMS_SCHEDULER job
        -- "BURGERQUICK_NIGHTLY_REFRESH" on the production server.

        NULL;  -- See DBMS_SCHEDULER for actual implementation
    END refresh_sales_temp_table;

    PROCEDURE refresh_inventory_temp_table IS
    BEGIN
        NULL;  -- See DBMS_SCHEDULER
    END refresh_inventory_temp_table;

    PROCEDURE refresh_customer_temp_table IS
    BEGIN
        NULL;  -- See DBMS_SCHEDULER
    END refresh_customer_temp_table;

END RPT_DAILY_SALES_V2_FINAL_USE_THIS;
/
