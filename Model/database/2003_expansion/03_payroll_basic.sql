-- ============================================================
-- Basic Payroll Tracking - 2003
-- Mike started a payroll calculation but never finished.
-- Sarah picked it up and built this. Different style from PKG_STORE_OPS.
-- ============================================================

CREATE TABLE TIME_SHEETS (
    timesheet_id    NUMBER PRIMARY KEY,
    employee_id     VARCHAR2(10) NOT NULL,
    work_date       DATE NOT NULL,
    hours_worked    NUMBER(4,2),
    shift_type      VARCHAR2(10),  -- 'OPEN', 'MID', 'CLOSE'
    approved_yn     CHAR(1) DEFAULT 'N',
    approved_by     VARCHAR2(10),
    created_dt      DATE DEFAULT SYSDATE
);

CREATE SEQUENCE seq_timesheet_id START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PROCEDURE sp_log_hours(
    p_employee_id IN VARCHAR2,
    p_work_date IN DATE,
    p_hours IN NUMBER,
    p_shift IN VARCHAR2
) IS
    v_ts_id NUMBER;
BEGIN
    SELECT seq_timesheet_id.NEXTVAL INTO v_ts_id FROM DUAL;
    INSERT INTO TIME_SHEETS (timesheet_id, employee_id, work_date, hours_worked, shift_type)
    VALUES (v_ts_id, p_employee_id, p_work_date, p_hours, p_shift);
    COMMIT;
END sp_log_hours;
/

-- Payroll calculation proc. Called by the manager every two weeks.
-- Mike wanted this in PKG_STORE_OPS but Sarah said separate concerns.
-- There's still tension about this. See PKG_STORE_OPS for the other
-- employee-related stuff. Yes, employee logic is split across two files.
-- Future developers: sorry. - Sarah
CREATE OR REPLACE PROCEDURE sp_calculate_payroll(
    p_employee_id IN VARCHAR2,
    p_start_date IN DATE,
    p_end_date IN DATE,
    p_total_hours OUT NUMBER,
    p_gross_pay OUT NUMBER
) IS
    v_hourly_rate NUMBER(6,2);
BEGIN
    SELECT NVL(SUM(hours_worked), 0)
    INTO p_total_hours
    FROM TIME_SHEETS
    WHERE employee_id = p_employee_id
      AND work_date BETWEEN p_start_date AND p_end_date;

    SELECT hourly_rate INTO v_hourly_rate
    FROM EMPLOYEES
    WHERE employee_id = p_employee_id;

    p_gross_pay := p_total_hours * v_hourly_rate;
END sp_calculate_payroll;
/
