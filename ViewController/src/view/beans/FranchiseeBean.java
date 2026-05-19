package view.beans;

import java.math.BigDecimal;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

import javax.faces.event.ActionEvent;

import oracle.jdbc.OracleTypes;

public class FranchiseeBean {

    private List<FranchiseeRow> franchises = new ArrayList<FranchiseeRow>();
    private String searchTerritory;
    private Integer selectedFranchiseId;
    private String selectedFranchiseName;
    private String message;

    private Integer editFranchiseId;
    private String editFranchiseCode;
    private String editFranchiseName;
    private String editOwnerFirst;
    private String editOwnerLast;
    private String editOwnerPhone;
    private String editOwnerEmail;
    private String editTerritory;
    private Integer editTotalLocations;
    private BigDecimal editRoyaltyPct;
    private String editAgreementStart;
    private String editAgreementEnd;
    private String editStatus;
    private boolean editing;
    private boolean showForm;

    private static final String DB_URL = "jdbc:oracle:thin:@localhost:1521/ORCLPDB1";
    private static final String DB_USER = "system";
    private static final String DB_PASS = "Oracle123!";

    public FranchiseeBean() {
        loadAllFranchises();
    }

    private Connection getConnection() throws SQLException {
        return DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
    }

    private FranchiseeRow mapRow(ResultSet rs) throws SQLException {
        FranchiseeRow r = new FranchiseeRow();
        r.franchiseId = rs.getInt("franchise_id");
        r.franchiseCode = rs.getString("franchise_code");
        r.franchiseName = rs.getString("franchise_name");
        r.ownerFirstNm = rs.getString("owner_first_nm");
        r.ownerLastNm = rs.getString("owner_last_nm");
        r.ownerPhone = rs.getString("owner_phone");
        r.ownerEmail = rs.getString("owner_email");
        r.territory = rs.getString("territory");
        r.totalLocations = rs.getInt("total_locations");
        r.royaltyPct = rs.getBigDecimal("royalty_pct");
        r.agreementStart = rs.getDate("agreement_start");
        r.agreementEnd = rs.getDate("agreement_end");
        r.status = rs.getString("status");
        return r;
    }

    public void loadAllFranchises() {
        franchises.clear();
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ ? = call FRANCHISE_PKG.get_all_franchises }")) {
            cs.registerOutParameter(1, OracleTypes.CURSOR);
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                while (rs.next()) {
                    franchises.add(mapRow(rs));
                }
            }
            message = null;
        } catch (SQLException e) {
            message = "DB Error: " + e.getMessage();
        }
    }

    public void searchFranchises(ActionEvent event) {
        selectedFranchiseId = null;
        selectedFranchiseName = null;
        if (searchTerritory == null || searchTerritory.trim().isEmpty()) {
            loadAllFranchises();
            return;
        }
        franchises.clear();
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ ? = call FRANCHISE_PKG.find_franchises_by_territory(?) }")) {
            cs.registerOutParameter(1, OracleTypes.CURSOR);
            cs.setString(2, searchTerritory.trim());
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                while (rs.next()) {
                    franchises.add(mapRow(rs));
                }
            }
            message = franchises.isEmpty() ? "No franchises found in " + searchTerritory : null;
        } catch (SQLException e) {
            message = "Search error: " + e.getMessage();
        }
    }

    public String clearSearch() {
        searchTerritory = null;
        selectedFranchiseId = null;
        selectedFranchiseName = null;
        message = null;
        loadAllFranchises();
        return null;
    }

    public String prepareAdd() {
        selectedFranchiseId = null;
        selectedFranchiseName = null;
        editFranchiseId = null;
        editFranchiseCode = null;
        editFranchiseName = null;
        editOwnerFirst = null;
        editOwnerLast = null;
        editOwnerPhone = null;
        editOwnerEmail = null;
        editTerritory = null;
        editTotalLocations = 1;
        editRoyaltyPct = null;
        editAgreementStart = null;
        editAgreementEnd = null;
        editStatus = null;
        editing = false;
        showForm = true;
        message = null;
        return null;
    }

    public String saveFranchise() {
        if (editing) {
            return doUpdate();
        }
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ call FRANCHISE_PKG.add_franchise(?,?,?,?,?,?) }")) {
            cs.setString(1, editFranchiseCode);
            cs.setString(2, editFranchiseName);
            cs.setString(3, editOwnerFirst);
            cs.setString(4, editOwnerLast);
            cs.setString(5, editTerritory);
            cs.setBigDecimal(6, editRoyaltyPct);
            cs.execute();
            message = "Franchise created successfully (status: PENDING).";
            loadAllFranchises();
            showForm = false;
        } catch (SQLException e) {
            message = "Error creating franchise: " + e.getMessage();
        }
        return null;
    }

    public String prepareEdit() {
        if (selectedFranchiseId == null) {
            message = "Select a franchise first.";
            return null;
        }
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ ? = call FRANCHISE_PKG.get_franchise(?) }")) {
            cs.registerOutParameter(1, OracleTypes.CURSOR);
            cs.setInt(2, selectedFranchiseId);
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                if (rs.next()) {
                    editFranchiseId = rs.getInt("franchise_id");
                    editFranchiseCode = rs.getString("franchise_code");
                    editFranchiseName = rs.getString("franchise_name");
                    editOwnerFirst = rs.getString("owner_first_nm");
                    editOwnerLast = rs.getString("owner_last_nm");
                    editOwnerPhone = rs.getString("owner_phone");
                    editOwnerEmail = rs.getString("owner_email");
                    editTerritory = rs.getString("territory");
                    editTotalLocations = rs.getInt("total_locations");
                    editRoyaltyPct = rs.getBigDecimal("royalty_pct");
                    Date as = rs.getDate("agreement_start");
                    Date ae = rs.getDate("agreement_end");
                    editAgreementStart = as != null ? as.toString() : null;
                    editAgreementEnd = ae != null ? ae.toString() : null;
                    editStatus = rs.getString("status");
                    editing = true;
                    showForm = true;
                }
            }
        } catch (SQLException e) {
            message = "Error loading franchise: " + e.getMessage();
        }
        return null;
    }

    private String doUpdate() {
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ call FRANCHISE_PKG.update_franchise(?,?,?,?,?,?,?,?,?,?,?,?,?) }")) {
            cs.setInt(1, editFranchiseId);
            cs.setString(2, editFranchiseCode);
            cs.setString(3, editFranchiseName);
            cs.setString(4, editOwnerFirst);
            cs.setString(5, editOwnerLast);
            cs.setString(6, editOwnerPhone);
            cs.setString(7, editOwnerEmail);
            cs.setString(8, editTerritory);
            cs.setInt(9, editTotalLocations != null ? editTotalLocations : 1);
            cs.setBigDecimal(10, editRoyaltyPct);
            cs.setString(11, editAgreementStart);
            cs.setString(12, editAgreementEnd);
            cs.setString(13, editStatus);
            cs.execute();
            message = "Franchise " + editFranchiseCode + " updated successfully.";
            editing = false;
            showForm = false;
            loadAllFranchises();
        } catch (SQLException e) {
            message = "Error updating franchise: " + e.getMessage();
        }
        return null;
    }

    public String deactivateFranchise() {
        if (selectedFranchiseId == null) {
            message = "Select a franchise first.";
            return null;
        }
        String name = selectedFranchiseName != null ? selectedFranchiseName : String.valueOf(selectedFranchiseId);
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ call FRANCHISE_PKG.deactivate_franchise(?) }")) {
            cs.setInt(1, selectedFranchiseId);
            cs.execute();
            message = "Franchise " + name + " deactivated.";
        } catch (SQLException e) {
            message = "Error: " + e.getMessage();
        }
        selectedFranchiseId = null;
        selectedFranchiseName = null;
        loadAllFranchises();
        return null;
    }

    public String selectFranchise() {
        if (selectedFranchiseId != null) {
            for (FranchiseeRow r : franchises) {
                if (selectedFranchiseId.equals(r.franchiseId)) {
                    selectedFranchiseName = r.franchiseCode + " - " + r.franchiseName;
                    return null;
                }
            }
        }
        selectedFranchiseName = null;
        return null;
    }

    public String cancelEdit() {
        showForm = false;
        editing = false;
        message = null;
        return null;
    }

    // ---- Getters / Setters ----
    public List<FranchiseeRow> getFranchises() { return franchises; }
    public void setFranchises(List<FranchiseeRow> f) { this.franchises = f; }
    public String getSearchTerritory() { return searchTerritory; }
    public void setSearchTerritory(String s) { this.searchTerritory = s; }
    public Integer getSelectedFranchiseId() { return selectedFranchiseId; }
    public void setSelectedFranchiseId(Integer i) { this.selectedFranchiseId = i; }
    public String getSelectedFranchiseName() { return selectedFranchiseName; }
    public void setSelectedFranchiseName(String s) { this.selectedFranchiseName = s; }
    public String getMessage() { return message; }
    public void setMessage(String s) { this.message = s; }
    public Integer getEditFranchiseId() { return editFranchiseId; }
    public void setEditFranchiseId(Integer i) { this.editFranchiseId = i; }
    public String getEditFranchiseCode() { return editFranchiseCode; }
    public void setEditFranchiseCode(String s) { this.editFranchiseCode = s; }
    public String getEditFranchiseName() { return editFranchiseName; }
    public void setEditFranchiseName(String s) { this.editFranchiseName = s; }
    public String getEditOwnerFirst() { return editOwnerFirst; }
    public void setEditOwnerFirst(String s) { this.editOwnerFirst = s; }
    public String getEditOwnerLast() { return editOwnerLast; }
    public void setEditOwnerLast(String s) { this.editOwnerLast = s; }
    public String getEditOwnerPhone() { return editOwnerPhone; }
    public void setEditOwnerPhone(String s) { this.editOwnerPhone = s; }
    public String getEditOwnerEmail() { return editOwnerEmail; }
    public void setEditOwnerEmail(String s) { this.editOwnerEmail = s; }
    public String getEditTerritory() { return editTerritory; }
    public void setEditTerritory(String s) { this.editTerritory = s; }
    public Integer getEditTotalLocations() { return editTotalLocations; }
    public void setEditTotalLocations(Integer i) { this.editTotalLocations = i; }
    public BigDecimal getEditRoyaltyPct() { return editRoyaltyPct; }
    public void setEditRoyaltyPct(BigDecimal b) { this.editRoyaltyPct = b; }
    public String getEditAgreementStart() { return editAgreementStart; }
    public void setEditAgreementStart(String s) { this.editAgreementStart = s; }
    public String getEditAgreementEnd() { return editAgreementEnd; }
    public void setEditAgreementEnd(String s) { this.editAgreementEnd = s; }
    public String getEditStatus() { return editStatus; }
    public void setEditStatus(String s) { this.editStatus = s; }
    public boolean isEditing() { return editing; }
    public boolean isShowForm() { return showForm; }

    public static class FranchiseeRow {
        public Integer franchiseId;
        public String franchiseCode, franchiseName, ownerFirstNm, ownerLastNm;
        public String ownerPhone, ownerEmail, territory;
        public Integer totalLocations;
        public BigDecimal royaltyPct;
        public java.util.Date agreementStart, agreementEnd;
        public String status;

        public Integer getFranchiseId() { return franchiseId; }
        public String getFranchiseCode() { return franchiseCode; }
        public String getFranchiseName() { return franchiseName; }
        public String getOwnerFirstNm() { return ownerFirstNm; }
        public String getOwnerLastNm() { return ownerLastNm; }
        public String getOwnerPhone() { return ownerPhone; }
        public String getOwnerEmail() { return ownerEmail; }
        public String getTerritory() { return territory; }
        public Integer getTotalLocations() { return totalLocations; }
        public BigDecimal getRoyaltyPct() { return royaltyPct; }
        public java.util.Date getAgreementStart() { return agreementStart; }
        public java.util.Date getAgreementEnd() { return agreementEnd; }
        public String getStatus() { return status; }
    }
}
