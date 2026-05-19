-- ============================================================
-- FRANCHISE_PKG Update - Added CRUD operations (2025)
-- Original (2006) had add_franchise, approve_franchise,
--   get_franchise_revenue, calc_royalties, calculate_franchise_order_total
-- This update adds: get_all_franchises, get_franchise,
--   find_franchises_by_territory, update_franchise, deactivate_franchise
-- ============================================================

CREATE OR REPLACE PACKAGE FRANCHISE_PKG AS

    -- Original (2006)
    PROCEDURE add_franchise(
        p_code VARCHAR2,
        p_name VARCHAR2,
        p_owner_first VARCHAR2,
        p_owner_last VARCHAR2,
        p_territory VARCHAR2,
        p_royalty_pct NUMBER
    );
    PROCEDURE approve_franchise(p_franchise_id NUMBER);
    FUNCTION get_franchise_revenue(p_franchise_id NUMBER, p_year NUMBER)
        RETURN NUMBER;
    FUNCTION calc_royalties(p_franchise_id NUMBER, p_quarter VARCHAR2)
        RETURN NUMBER;
    FUNCTION calculate_franchise_order_total(p_franchise_id NUMBER) RETURN NUMBER;

    -- New CRUD (2025)
    FUNCTION get_all_franchises RETURN SYS_REFCURSOR;
    FUNCTION get_franchise(p_franchise_id NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION find_franchises_by_territory(p_territory VARCHAR2) RETURN SYS_REFCURSOR;
    PROCEDURE update_franchise(
        p_franchise_id NUMBER,
        p_franchise_code VARCHAR2,
        p_franchise_name VARCHAR2,
        p_owner_first VARCHAR2,
        p_owner_last VARCHAR2,
        p_owner_phone VARCHAR2,
        p_owner_email VARCHAR2,
        p_territory VARCHAR2,
        p_total_locations NUMBER,
        p_royalty_pct NUMBER,
        p_agreement_start VARCHAR2,
        p_agreement_end VARCHAR2,
        p_status VARCHAR2
    );
    PROCEDURE deactivate_franchise(p_franchise_id NUMBER);

END FRANCHISE_PKG;
/

CREATE OR REPLACE PACKAGE BODY FRANCHISE_PKG AS

    -- ============================================================
    -- Original procedures (2006)
    -- ============================================================

    PROCEDURE add_franchise(
        p_code VARCHAR2,
        p_name VARCHAR2,
        p_owner_first VARCHAR2,
        p_owner_last VARCHAR2,
        p_territory VARCHAR2,
        p_royalty_pct NUMBER
    ) IS
        v_franchise_id NUMBER;
        v_owner_id NUMBER;
    BEGIN
        SELECT seq_franchise_id.NEXTVAL INTO v_franchise_id FROM DUAL;
        SELECT seq_owner_id.NEXTVAL INTO v_owner_id FROM DUAL;

        INSERT INTO FRANCHISES (franchise_id, franchise_code, franchise_name,
            owner_first_nm, owner_last_nm, territory, royalty_pct, status)
        VALUES (v_franchise_id, p_code, p_name, p_owner_first, p_owner_last,
            p_territory, p_royalty_pct, 'PENDING');

        INSERT INTO FRANCHISE_OWNERS (owner_id, first_nm, last_nm)
        VALUES (v_owner_id, p_owner_first, p_owner_last);

        INSERT INTO FRANCHISE_OWNER_LINK (link_id, franchise_id, owner_id, ownership_pct)
        VALUES (seq_fol_id.NEXTVAL, v_franchise_id, v_owner_id, 100);

        COMMIT;
    END add_franchise;

    PROCEDURE approve_franchise(p_franchise_id NUMBER) IS
    BEGIN
        UPDATE FRANCHISES SET status = 'ACTIVE' WHERE franchise_id = p_franchise_id;
        COMMIT;
    END approve_franchise;

    FUNCTION get_franchise_revenue(p_franchise_id NUMBER, p_year NUMBER)
        RETURN NUMBER IS
        v_total NUMBER(12,2) := 0;
    BEGIN
        SELECT NVL(SUM(o.total_amount), 0)
        INTO v_total
        FROM ORDERS o
        JOIN STORES s ON o.store_id = s.store_id
        WHERE s.store_number IN (
            SELECT store_number FROM STORES s2, FRANCHISES f
            WHERE f.franchise_id = p_franchise_id
              AND s2.city IN (SELECT city FROM STORES)
        )
        AND EXTRACT(YEAR FROM o.order_dt) = p_year;
        RETURN v_total;
    END get_franchise_revenue;

    FUNCTION calc_royalties(p_franchise_id NUMBER, p_quarter VARCHAR2)
        RETURN NUMBER IS
        v_revenue NUMBER(12,2);
        v_royalty_pct NUMBER(5,2);
        v_royalties NUMBER(12,2);
    BEGIN
        v_revenue := get_franchise_revenue(p_franchise_id, 2007);
        SELECT royalty_pct INTO v_royalty_pct
        FROM FRANCHISES WHERE franchise_id = p_franchise_id;
        v_royalties := v_revenue * (v_royalty_pct / 100);
        RETURN v_royalties;
    END calc_royalties;

    FUNCTION calculate_franchise_order_total(p_franchise_id NUMBER)
        RETURN NUMBER IS
        v_total NUMBER(12,2);
    BEGIN
        SELECT NVL(SUM(o.total_amount + o.tax_amount), 0)
        INTO v_total
        FROM ORDERS o
        JOIN STORES s ON o.store_id = s.store_id
        WHERE s.store_number IN (
            SELECT store_number FROM STORES s2, FRANCHISES f
            WHERE f.franchise_id = p_franchise_id
              AND s2.city IN (SELECT city FROM STORES)
        );
        RETURN v_total;
    END calculate_franchise_order_total;

    -- ============================================================
    -- New CRUD procedures (2025)
    -- ============================================================

    FUNCTION get_all_franchises RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT franchise_id, franchise_code, franchise_name,
                   owner_first_nm, owner_last_nm, owner_phone, owner_email,
                   territory, total_locations, royalty_pct,
                   agreement_start, agreement_end, status
            FROM FRANCHISES
            WHERE status != 'INACTIVE'
            ORDER BY franchise_id;
        RETURN v_cursor;
    END;

    FUNCTION get_franchise(p_franchise_id NUMBER) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT * FROM FRANCHISES WHERE franchise_id = p_franchise_id;
        RETURN v_cursor;
    END;

    FUNCTION find_franchises_by_territory(p_territory VARCHAR2) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT franchise_id, franchise_code, franchise_name,
                   owner_first_nm, owner_last_nm, owner_phone, owner_email,
                   territory, total_locations, royalty_pct,
                   agreement_start, agreement_end, status
            FROM FRANCHISES
            WHERE UPPER(territory) LIKE '%' || UPPER(p_territory) || '%'
              AND status != 'INACTIVE'
            ORDER BY franchise_id;
        RETURN v_cursor;
    END;

    PROCEDURE update_franchise(
        p_franchise_id NUMBER,
        p_franchise_code VARCHAR2,
        p_franchise_name VARCHAR2,
        p_owner_first VARCHAR2,
        p_owner_last VARCHAR2,
        p_owner_phone VARCHAR2,
        p_owner_email VARCHAR2,
        p_territory VARCHAR2,
        p_total_locations NUMBER,
        p_royalty_pct NUMBER,
        p_agreement_start VARCHAR2,
        p_agreement_end VARCHAR2,
        p_status VARCHAR2
    ) IS
    BEGIN
        UPDATE FRANCHISES
        SET franchise_code = p_franchise_code,
            franchise_name = p_franchise_name,
            owner_first_nm = p_owner_first,
            owner_last_nm = p_owner_last,
            owner_phone = p_owner_phone,
            owner_email = p_owner_email,
            territory = p_territory,
            total_locations = p_total_locations,
            royalty_pct = p_royalty_pct,
            agreement_start = TO_DATE(p_agreement_start, 'YYYY-MM-DD'),
            agreement_end = TO_DATE(p_agreement_end, 'YYYY-MM-DD'),
            status = p_status,
            last_mod_date = SYSDATE,
            last_mod_user = 'SYSTEM'
        WHERE franchise_id = p_franchise_id;
        COMMIT;
    END;

    PROCEDURE deactivate_franchise(p_franchise_id NUMBER) IS
    BEGIN
        UPDATE FRANCHISES SET status = 'INACTIVE', last_mod_date = SYSDATE, last_mod_user = 'SYSTEM'
        WHERE franchise_id = p_franchise_id;
        COMMIT;
    END;

END FRANCHISE_PKG;
/
