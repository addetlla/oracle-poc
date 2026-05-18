-- ============================================================
-- Customer Management Procedures - 2009
-- Author: Jason Miller
-- ============================================================
-- Basic CRUD for the CUSTOMERS table.
-- I'm using standalone functions like Sarah. Mixing styles, I know.
-- ============================================================

CREATE OR REPLACE PROCEDURE sp_register_customer(
    p_first_name IN VARCHAR2,
    p_last_name IN VARCHAR2,
    p_email IN VARCHAR2,
    p_phone IN VARCHAR2,
    p_password IN VARCHAR2,  -- Already hashed by the Java layer (hopefully)
    p_cust_id OUT NUMBER
) IS
BEGIN
    SELECT seq_cust_id.NEXTVAL INTO p_cust_id FROM DUAL;

    INSERT INTO CUSTOMERS (cust_id, first_name, last_name, email, phone, password_hash)
    VALUES (p_cust_id, p_first_name, p_last_name, p_email, p_phone, p_password);

    COMMIT;
END sp_register_customer;
/

-- Check if email already exists
CREATE OR REPLACE FUNCTION sp_check_email_exists(p_email VARCHAR2) RETURN CHAR IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM CUSTOMERS WHERE email = p_email;
    IF v_count > 0 THEN RETURN 'Y'; ELSE RETURN 'N'; END IF;
END sp_check_email_exists;
/

-- Get customer by email (for login)
CREATE OR REPLACE FUNCTION sp_get_customer_by_email(p_email VARCHAR2) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
BEGIN
    OPEN v_cursor FOR
        SELECT cust_id, first_name, last_name, email, phone, password_hash
        FROM CUSTOMERS
        WHERE email = p_email AND is_active = 'Y';
    RETURN v_cursor;
END sp_get_customer_by_email;
/

-- ============================================================
-- NOTE ADDED 2012:
-- The loyalty team created their own customer lookup in LOYALTY_PKG.
-- They didn't know sp_get_customer_by_email existed.
-- So now there are two completely different ways to look up a customer.
-- This one returns a cursor. Theirs returns a custom type.
-- The web app uses this one. The mobile app uses theirs.
-- Don't merge them, both are in production with different consumers.
-- ============================================================
