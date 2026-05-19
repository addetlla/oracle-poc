package view.beans;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

import javax.faces.event.ActionEvent;

import oracle.jdbc.OracleTypes;

public class StoreBean {

    private List<StoreRow> stores = new ArrayList<StoreRow>();
    private String searchCity;
    private Integer selectedStoreId;
    private String selectedStoreName;
    private String message;

    private Integer editStoreId;
    private String editStoreNumber;
    private String editStoreName;
    private String editAddress;
    private String editCity;
    private String editState;
    private String editZip;
    private String editPhone;
    private String editManagerId;
    private Integer editSeatingCapacity;
    private String editDriveThruYn;
    private String editIsOpen;
    private boolean editing;
    private boolean showForm;

    private static final String DB_URL = "jdbc:oracle:thin:@localhost:1521/ORCLPDB1";
    private static final String DB_USER = "system";
    private static final String DB_PASS = "Oracle123!";

    public StoreBean() {
        loadAllStores();
    }

    private Connection getConnection() throws SQLException {
        return DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
    }

    private StoreRow mapRow(ResultSet rs) throws SQLException {
        StoreRow r = new StoreRow();
        r.storeId = rs.getInt("store_id");
        r.storeNumber = rs.getString("store_number");
        r.storeName = rs.getString("store_name");
        r.address = rs.getString("address_line1");
        r.city = rs.getString("city");
        r.state = rs.getString("state");
        r.zip = rs.getString("zip");
        r.phone = rs.getString("phone");
        r.managerId = rs.getString("manager_id");
        r.seatingCapacity = rs.getInt("seating_capacity");
        r.driveThruYn = rs.getString("drive_thru_yn");
        r.isOpen = rs.getString("is_open");
        return r;
    }

    public void loadAllStores() {
        stores.clear();
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ ? = call PKG_STORE_OPS.get_all_stores }")) {
            cs.registerOutParameter(1, OracleTypes.CURSOR);
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                while (rs.next()) {
                    stores.add(mapRow(rs));
                }
            }
            message = null;
        } catch (SQLException e) {
            message = "DB Error: " + e.getMessage();
        }
    }

    public void searchStores(ActionEvent event) {
        selectedStoreId = null;
        selectedStoreName = null;
        if (searchCity == null || searchCity.trim().isEmpty()) {
            loadAllStores();
            return;
        }
        stores.clear();
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ ? = call PKG_STORE_OPS.find_stores_by_city(?) }")) {
            cs.registerOutParameter(1, OracleTypes.CURSOR);
            cs.setString(2, searchCity.trim());
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                while (rs.next()) {
                    stores.add(mapRow(rs));
                }
            }
            message = stores.isEmpty() ? "No stores found in " + searchCity : null;
        } catch (SQLException e) {
            message = "Search error: " + e.getMessage();
        }
    }

    public String clearSearch() {
        searchCity = null;
        selectedStoreId = null;
        selectedStoreName = null;
        message = null;
        loadAllStores();
        return null;
    }

    public String prepareAdd() {
        selectedStoreId = null;
        selectedStoreName = null;
        editStoreId = null;
        editStoreNumber = null;
        editStoreName = null;
        editAddress = null;
        editCity = null;
        editState = null;
        editZip = null;
        editPhone = null;
        editManagerId = null;
        editSeatingCapacity = 50;
        editDriveThruYn = "Y";
        editing = false;
        showForm = true;
        message = null;
        return null;
    }

    public String saveStore() {
        if (editing) {
            return doUpdate();
        }
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ call PKG_STORE_OPS.create_store(?,?,?,?,?,?,?,?,?,?) }")) {
            cs.setString(1, editStoreNumber);
            cs.setString(2, editStoreName);
            cs.setString(3, editAddress);
            cs.setString(4, editCity);
            cs.setString(5, editState);
            cs.setString(6, editZip);
            cs.setString(7, editPhone);
            cs.setString(8, editManagerId);
            cs.setInt(9, editSeatingCapacity != null ? editSeatingCapacity : 50);
            cs.setString(10, editDriveThruYn != null ? editDriveThruYn : "Y");
            cs.execute();
            message = "Store created successfully.";
            loadAllStores();
            showForm = false;
        } catch (SQLException e) {
            message = "Error creating store: " + e.getMessage();
        }
        return null;
    }

    public String prepareEdit() {
        if (selectedStoreId == null) {
            message = "Select a store first.";
            return null;
        }
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ ? = call PKG_STORE_OPS.get_store(?) }")) {
            cs.registerOutParameter(1, OracleTypes.CURSOR);
            cs.setInt(2, selectedStoreId);
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                if (rs.next()) {
                    editStoreId = rs.getInt("store_id");
                    editStoreNumber = rs.getString("store_number");
                    editStoreName = rs.getString("store_name");
                    editAddress = rs.getString("address_line1");
                    editCity = rs.getString("city");
                    editState = rs.getString("state");
                    editZip = rs.getString("zip");
                    editPhone = rs.getString("phone");
                    editManagerId = rs.getString("manager_id");
                    editSeatingCapacity = rs.getInt("seating_capacity");
                    editDriveThruYn = rs.getString("drive_thru_yn");
                    editIsOpen = rs.getString("is_open");
                    editing = true;
                    showForm = true;
                }
            }
        } catch (SQLException e) {
            message = "Error loading store: " + e.getMessage();
        }
        return null;
    }

    private String doUpdate() {
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ call PKG_STORE_OPS.update_store(?,?,?,?,?,?,?,?,?,?,?,?) }")) {
            cs.setInt(1, editStoreId);
            cs.setString(2, editStoreNumber);
            cs.setString(3, editStoreName);
            cs.setString(4, editAddress);
            cs.setString(5, editCity);
            cs.setString(6, editState);
            cs.setString(7, editZip);
            cs.setString(8, editPhone);
            cs.setString(9, editManagerId);
            cs.setInt(10, editSeatingCapacity != null ? editSeatingCapacity : 50);
            cs.setString(11, editDriveThruYn != null ? editDriveThruYn : "Y");
            cs.setString(12, editIsOpen != null ? editIsOpen : "Y");
            cs.execute();
            message = "Store " + editStoreNumber + " updated successfully.";
            editing = false;
            showForm = false;
            loadAllStores();
        } catch (SQLException e) {
            message = "Error updating store: " + e.getMessage();
        }
        return null;
    }

    public String closeStore() {
        if (selectedStoreId == null) {
            message = "Select a store first.";
            return null;
        }
        String name = selectedStoreName != null ? selectedStoreName : String.valueOf(selectedStoreId);
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ call PKG_STORE_OPS.close_store(?) }")) {
            cs.setInt(1, selectedStoreId);
            cs.execute();
            message = "Store " + name + " closed.";
        } catch (SQLException e) {
            message = "Error: " + e.getMessage();
        }
        selectedStoreId = null;
        selectedStoreName = null;
        loadAllStores();
        return null;
    }

    public String selectStore() {
        if (selectedStoreId != null) {
            for (StoreRow r : stores) {
                if (selectedStoreId.equals(r.storeId)) {
                    selectedStoreName = r.storeNumber + " - " + r.storeName;
                    return null;
                }
            }
        }
        selectedStoreName = null;
        return null;
    }

    public String cancelEdit() {
        showForm = false;
        editing = false;
        message = null;
        return null;
    }

    // ---- Getters / Setters ----
    public List<StoreRow> getStores() { return stores; }
    public void setStores(List<StoreRow> s) { this.stores = s; }
    public String getSearchCity() { return searchCity; }
    public void setSearchCity(String s) { this.searchCity = s; }
    public Integer getSelectedStoreId() { return selectedStoreId; }
    public void setSelectedStoreId(Integer s) { this.selectedStoreId = s; }
    public String getSelectedStoreName() { return selectedStoreName; }
    public void setSelectedStoreName(String s) { this.selectedStoreName = s; }
    public String getMessage() { return message; }
    public void setMessage(String s) { this.message = s; }
    public Integer getEditStoreId() { return editStoreId; }
    public void setEditStoreId(Integer s) { this.editStoreId = s; }
    public String getEditStoreNumber() { return editStoreNumber; }
    public void setEditStoreNumber(String s) { this.editStoreNumber = s; }
    public String getEditStoreName() { return editStoreName; }
    public void setEditStoreName(String s) { this.editStoreName = s; }
    public String getEditAddress() { return editAddress; }
    public void setEditAddress(String s) { this.editAddress = s; }
    public String getEditCity() { return editCity; }
    public void setEditCity(String s) { this.editCity = s; }
    public String getEditState() { return editState; }
    public void setEditState(String s) { this.editState = s; }
    public String getEditZip() { return editZip; }
    public void setEditZip(String s) { this.editZip = s; }
    public String getEditPhone() { return editPhone; }
    public void setEditPhone(String s) { this.editPhone = s; }
    public String getEditManagerId() { return editManagerId; }
    public void setEditManagerId(String s) { this.editManagerId = s; }
    public Integer getEditSeatingCapacity() { return editSeatingCapacity; }
    public void setEditSeatingCapacity(Integer i) { this.editSeatingCapacity = i; }
    public String getEditDriveThruYn() { return editDriveThruYn; }
    public void setEditDriveThruYn(String s) { this.editDriveThruYn = s; }
    public String getEditIsOpen() { return editIsOpen; }
    public void setEditIsOpen(String s) { this.editIsOpen = s; }
    public boolean isEditing() { return editing; }
    public boolean isShowForm() { return showForm; }

    public static class StoreRow {
        public Integer storeId;
        public String storeNumber, storeName, address, city, state, zip, phone, managerId;
        public Integer seatingCapacity;
        public String driveThruYn, isOpen;

        public Integer getStoreId() { return storeId; }
        public String getStoreNumber() { return storeNumber; }
        public String getStoreName() { return storeName; }
        public String getAddress() { return address; }
        public String getCity() { return city; }
        public String getState() { return state; }
        public String getZip() { return zip; }
        public String getPhone() { return phone; }
        public String getManagerId() { return managerId; }
        public Integer getSeatingCapacity() { return seatingCapacity; }
        public String getDriveThruYn() { return driveThruYn; }
        public String getIsOpen() { return isOpen; }
    }
}
