-- ============================================================
-- FRANCHISE_PKG - Franchise Management Package
-- Team: Raj, Priya, Anil (Offshore Dev Team)
-- Created: March 2006
-- ============================================================
-- We used a package like Mike's PKG_STORE_OPS, but our own structure.
-- We call some of Sarah's procs too. Not sure if we should.
-- If something breaks, contact Raj (+91 xxxxx xxxxx).
-- ============================================================

CREATE OR REPLACE PACKAGE FRANCHISE_PKG AS

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

    -- Added 2007: Calculate royalties owed
    FUNCTION calc_royalties(p_franchise_id NUMBER, p_quarter VARCHAR2)
        RETURN NUMBER;

    -- This procedure calculates orders under a franchise.
    -- We call Sarah's sp_OrderProcessing because it already works.
    -- BUT we also have our own calculation that's slightly different.
    -- Our calculation includes tax in the subtotal (business requirement from franchise ops).
    -- That's why this exists separately. See sp_get_order_total for the non-franchise version.
    FUNCTION calculate_franchise_order_total(p_franchise_id NUMBER) RETURN NUMBER;

END FRANCHISE_PKG;
/

CREATE OR REPLACE PACKAGE BODY FRANCHISE_PKG AS

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

        -- We also insert into the link table (though it's half-finished)
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
        -- Sum orders across all stores belonging to this franchise
        -- This joins across Mike's, Sarah's, and our tables. If any of them
        -- change their schema, this breaks. But it works for now.
        SELECT NVL(SUM(o.total_amount), 0)
        INTO v_total
        FROM ORDERS o
        JOIN STORES s ON o.store_id = s.store_id
        WHERE s.store_number IN (
            -- TODO: Add franchise-to-store mapping. Currently stores aren't
            -- actually linked to franchises in the DB. We approximate via territory.
            -- Anil, 2006. Still TODO. Raj, 2008. Still TODO. Priya, 2010 (now on other project).
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
        -- Determine year from quarter string like 'Q1-2007'
        -- Actually we just hardcode the date range. This was faster.
        -- Someone should fix this to parse the quarter properly.

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
        -- This calculates total INCLUDING tax, unlike sp_get_order_total
        -- which returns pre-tax subtotal. Franchise ops needs tax-inclusive.
        -- See email thread "Royalty calculation discrepancy - URGENT" from Oct 2007.
        SELECT NVL(SUM(o.total_amount + o.tax_amount), 0)
        INTO v_total
        FROM ORDERS o
        JOIN STORES s ON o.store_id = s.store_id
        WHERE s.store_number IN (
            SELECT store_number FROM STORES s2, FRANCHISES f
            WHERE f.franchise_id = p_franchise_id
              AND s2.city IN (SELECT city FROM STORES)  -- Same hack as above
        );
        RETURN v_total;
    END calculate_franchise_order_total;

END FRANCHISE_PKG;
/
