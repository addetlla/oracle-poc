-- ============================================================
-- USER_SERVICE - Half-Built Microservice Database
-- Author: Marcus (Senior Dev, CTO's modernization team)
-- Started: June 2018 | Abandoned: August 2018
-- ============================================================
-- The CTO's plan was to break the monolith into microservices.
-- This was the "User Service" - it was supposed to own all user/
-- customer/employee data and expose it via REST.
--
-- We got as far as creating the schema before the CTO left.
-- Marcus was reassigned to "more critical work" (pandemic delivery
-- features in 2020 - see 2020_delivery/01_delivery_pkg.sql).
--
-- DO NOT USE THESE TABLES. They are not populated and have no
-- relationship to the actual EMPLOYEES or CUSTOMERS tables.
-- We were supposed to do a data migration from the old tables
-- but never got to it.
-- - Marcus, August 2018
-- ============================================================

-- A clean, normalized user table. The OPPOSITE of everything else.
-- Normal form, proper constraints, UUID primary keys, bcrypt hashes.
-- Completely incompatible with every other table in the database.
CREATE TABLE USERS (
    user_uuid       VARCHAR2(36) PRIMARY KEY,   -- UUID format. NOTHING else uses UUIDs.
    email           VARCHAR2(255) UNIQUE NOT NULL,
    password_hash   VARCHAR2(255) NOT NULL,     -- bcrypt, not SHA-256 like CUSTOMERS
    full_name       VARCHAR2(200) NOT NULL,     -- Single field vs EMPLOYEES/CUSTOMERS first+last
    user_type       VARCHAR2(20) NOT NULL,      -- 'EMPLOYEE', 'CUSTOMER', 'FRANCHISEE'
    phone           VARCHAR2(20),
    is_verified     CHAR(1) DEFAULT 'N',
    is_active       CHAR(1) DEFAULT 'Y',
    created_at      TIMESTAMP DEFAULT SYSTIMESTAMP,  -- TIMESTAMP vs everyone else's DATE
    updated_at      TIMESTAMP,
    deleted_at      TIMESTAMP,                       -- Soft delete. Nobody else does this.
    CONSTRAINT chk_user_type CHECK (user_type IN ('EMPLOYEE', 'CUSTOMER', 'FRANCHISEE'))
);

-- Junction table connecting users to their various roles
-- This was going to replace EMPLOYEES.employee_id, CUSTOMERS.cust_id, etc.
CREATE TABLE USER_ROLES (
    role_id         NUMBER PRIMARY KEY,
    user_uuid       VARCHAR2(36) NOT NULL,
    role_type       VARCHAR2(30) NOT NULL,
    store_id        NUMBER,       -- Nullable - only for employees
    franchise_id    NUMBER,       -- Nullable - only for franchisees
    assigned_at     TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_ur_user FOREIGN KEY (user_uuid) REFERENCES USERS(user_uuid)
);

CREATE SEQUENCE seq_user_role_id START WITH 1 INCREMENT BY 1;

-- ============================================================
-- MIGRATION NOTES (for whoever picks this up):
--
-- To migrate EMPLOYEES -> USERS:
--   SELECT employee_id, first_name || ' ' || last_name, 'EMPLOYEE', phone
--   FROM EMPLOYEES WHERE is_active = 'Y';
--
-- To migrate CUSTOMERS -> USERS:
--   SELECT cust_id, first_name || ' ' || last_name, 'CUSTOMER', phone
--   FROM CUSTOMERS WHERE is_active = 'Y';
--
-- The password hashes are incompatible (SHA-256 vs bcrypt).
-- We'd need a migration script that re-hashes everyone's password.
-- That means forcing all users to reset their password.
-- The PM said "absolutely not" and that's when this project died.
-- ============================================================

-- Stored procedure stub that was never implemented
CREATE OR REPLACE PROCEDURE migrate_users_to_new_schema AS
BEGIN
    -- TODO: Implement migration from EMPLOYEES and CUSTOMERS to USERS
    -- TODO: Handle password re-hashing (SHA-256 -> bcrypt)
    -- TODO: Handle UUID generation for existing users
    -- TODO: Backfill USER_ROLES table
    -- TODO: Update all stored procedures to use user_uuid instead of employee_id/cust_id
    -- TODO: Update all foreign keys in ORDERS, ONLINE_ORDERS, TIME_SHEETS, etc.
    -- TODO: Get sign-off from all 12 teams that depend on these tables
    -- TODO: Schedule downtime (estimated 8 hours for migration)
    -- TODO: Write rollback plan
    --
    -- Estimated effort: 3 months with a team of 4
    -- Actual budget remaining: $0 (CTO's budget was reallocated)
    --
    -- Filed under: "Phase 2 - Q4 2018" (never happened)
    -- Filed under: "Phase 2 - Q2 2019" (never happened)
    -- Not filed anywhere after 2019.

    NULL;
END migrate_users_to_new_schema;
/
