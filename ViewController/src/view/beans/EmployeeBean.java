package view.beans;

import java.math.BigDecimal;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

import javax.faces.event.ActionEvent;

import oracle.jdbc.OracleTypes;

public class EmployeeBean {

    private List<EmployeeRow> employees = new ArrayList<EmployeeRow>();
    private String searchStoreNumber;
    private String selectedEmployeeId;
    private String message;

    private String selectedEmployeeName;

    private String editEmployeeId;
    private String editFirstName;
    private String editLastName;
    private String editPosition;
    private BigDecimal editHourlyRate;
    private String editStoreNumber;
    private boolean editing;
    private boolean showForm;

    private static final String DB_URL = "jdbc:oracle:thin:@localhost:1521/ORCLPDB1";
    private static final String DB_USER = "system";
    private static final String DB_PASS = "Oracle123!";

    public EmployeeBean() {
        loadAllEmployees();
    }

    private Connection getConnection() throws SQLException {
        return DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
    }

    private EmployeeRow mapRow(ResultSet rs) throws SQLException {
        EmployeeRow r = new EmployeeRow();
        r.employeeId = rs.getString("employee_id");
        r.firstName = rs.getString("first_name");
        r.lastName = rs.getString("last_name");
        r.position = rs.getString("position");
        r.hourlyRate = rs.getBigDecimal("hourly_rate");
        r.storeNumber = rs.getString("store_number");
        return r;
    }

    // ---- PKG_STORE_OPS.get_all_employees ----
    public void loadAllEmployees() {
        employees.clear();
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ ? = call PKG_STORE_OPS.get_all_employees }")) {
            cs.registerOutParameter(1, OracleTypes.CURSOR);
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                while (rs.next()) {
                    employees.add(mapRow(rs));
                }
            }
            message = null;
        } catch (SQLException e) {
            message = "DB Error: " + e.getMessage();
        }
    }

    // ---- PKG_STORE_OPS.find_employees_by_store ----
    public void searchEmployees(ActionEvent event) {
        selectedEmployeeId = null;
        selectedEmployeeName = null;
        if (searchStoreNumber == null || searchStoreNumber.trim().isEmpty()) {
            loadAllEmployees();
            return;
        }
        employees.clear();
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ ? = call PKG_STORE_OPS.find_employees_by_store(?) }")) {
            cs.registerOutParameter(1, OracleTypes.CURSOR);
            cs.setString(2, searchStoreNumber.trim());
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                while (rs.next()) {
                    employees.add(mapRow(rs));
                }
            }
            message = employees.isEmpty() ? "No employees in store " + searchStoreNumber : null;
        } catch (SQLException e) {
            message = "Search error: " + e.getMessage();
        }
    }

    // ---- clear search ----
    public String clearSearch() {
        searchStoreNumber = null;
        selectedEmployeeId = null;
        selectedEmployeeName = null;
        message = null;
        loadAllEmployees();
        return null;
    }

    // ---- PKG_STORE_OPS.hire_employee ----
    public String prepareAdd() {
        selectedEmployeeId = null;
        selectedEmployeeName = null;
        editEmployeeId = null;
        editFirstName = null;
        editLastName = null;
        editPosition = null;
        editHourlyRate = null;
        editStoreNumber = null;
        editing = false;
        showForm = true;
        message = null;
        return null;
    }

    public String saveEmployee() {
        if (editing) {
            return doUpdate();
        }
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ call PKG_STORE_OPS.hire_employee(?,?,?,?,?,?) }")) {
            cs.setString(1, editFirstName);
            cs.setString(2, editLastName);
            cs.setString(3, "000-00-0000"); // SSN placeholder
            cs.setString(4, editStoreNumber != null ? editStoreNumber : "1");
            cs.setString(5, editPosition);
            cs.setBigDecimal(6, editHourlyRate);
            cs.execute();
            message = "Employee hired successfully.";
            loadAllEmployees();
            showForm = false;
        } catch (SQLException e) {
            message = "Error hiring: " + e.getMessage();
        }
        return null;
    }

    // ---- PKG_STORE_OPS.update_employee ----
    public String prepareEdit() {
        if (selectedEmployeeId == null) {
            message = "Select an employee first.";
            return null;
        }
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ ? = call PKG_STORE_OPS.get_employee(?) }")) {
            cs.registerOutParameter(1, OracleTypes.CURSOR);
            cs.setString(2, selectedEmployeeId);
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                if (rs.next()) {
                    editEmployeeId = rs.getString("employee_id");
                    editFirstName = rs.getString("first_name");
                    editLastName = rs.getString("last_name");
                    editPosition = rs.getString("position");
                    editHourlyRate = rs.getBigDecimal("hourly_rate");
                    editStoreNumber = rs.getString("store_number");
                    editing = true;
                    showForm = true;
                }
            }
        } catch (SQLException e) {
            message = "Error loading: " + e.getMessage();
        }
        return null;
    }

    private String doUpdate() {
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ call PKG_STORE_OPS.update_employee(?,?,?,?,?,?) }")) {
            cs.setString(1, editEmployeeId);
            cs.setString(2, editFirstName);
            cs.setString(3, editLastName);
            cs.setString(4, editPosition);
            cs.setBigDecimal(5, editHourlyRate);
            cs.setString(6, editStoreNumber);
            cs.execute();
            message = "Employee " + editEmployeeId + " updated successfully.";
            editing = false;
            showForm = false;
            loadAllEmployees();
        } catch (SQLException e) {
            message = "Error updating: " + e.getMessage();
        }
        return null;
    }

    // ---- PKG_STORE_OPS.fire_employee ----
    public String deleteEmployee() {
        if (selectedEmployeeId == null) {
            message = "Select an employee first.";
            return null;
        }
        String name = selectedEmployeeName != null ? selectedEmployeeName : selectedEmployeeId;
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ call PKG_STORE_OPS.fire_employee(?) }")) {
            cs.setString(1, selectedEmployeeId);
            cs.execute();
            message = "Employee " + name + " deactivated.";
        } catch (SQLException e) {
            message = "Error: " + e.getMessage();
        }
        selectedEmployeeId = null;
        selectedEmployeeName = null;
        loadAllEmployees();
        return null;
    }

    public String selectEmployee() {
        if (selectedEmployeeId != null) {
            for (EmployeeRow r : employees) {
                if (selectedEmployeeId.equals(r.employeeId)) {
                    selectedEmployeeName = r.firstName + " " + r.lastName + " (" + r.employeeId + ")";
                    return null;
                }
            }
        }
        selectedEmployeeName = null;
        return null;
    }

    public String cancelEdit() {
        showForm = false;
        editing = false;
        message = null;
        return null;
    }

    // ---- Getters / Setters ----
    public List<EmployeeRow> getEmployees() { return employees; }
    public void setEmployees(List<EmployeeRow> e) { this.employees = e; }
    public String getSearchStoreNumber() { return searchStoreNumber; }
    public void setSearchStoreNumber(String s) { this.searchStoreNumber = s; }
    public String getSelectedEmployeeId() { return selectedEmployeeId; }
    public void setSelectedEmployeeId(String s) { this.selectedEmployeeId = s; }
    public String getSelectedEmployeeName() { return selectedEmployeeName; }
    public void setSelectedEmployeeName(String s) { this.selectedEmployeeName = s; }
    public String getMessage() { return message; }
    public void setMessage(String s) { this.message = s; }
    public String getEditEmployeeId() { return editEmployeeId; }
    public void setEditEmployeeId(String s) { this.editEmployeeId = s; }
    public String getEditFirstName() { return editFirstName; }
    public void setEditFirstName(String s) { this.editFirstName = s; }
    public String getEditLastName() { return editLastName; }
    public void setEditLastName(String s) { this.editLastName = s; }
    public String getEditPosition() { return editPosition; }
    public void setEditPosition(String s) { this.editPosition = s; }
    public BigDecimal getEditHourlyRate() { return editHourlyRate; }
    public void setEditHourlyRate(BigDecimal b) { this.editHourlyRate = b; }
    public String getEditStoreNumber() { return editStoreNumber; }
    public void setEditStoreNumber(String s) { this.editStoreNumber = s; }
    public boolean isEditing() { return editing; }
    public boolean isShowForm() { return showForm; }

    public static class EmployeeRow {
        public String employeeId, firstName, lastName, position, storeNumber;
        public BigDecimal hourlyRate;
        public String getEmployeeId() { return employeeId; }
        public String getFirstName() { return firstName; }
        public String getLastName() { return lastName; }
        public String getPosition() { return position; }
        public BigDecimal getHourlyRate() { return hourlyRate; }
        public String getStoreNumber() { return storeNumber; }
    }
}
