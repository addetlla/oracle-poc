package view.beans;

import java.math.BigDecimal;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

import javax.faces.event.ActionEvent;

import oracle.jdbc.OracleTypes;

public class InventoryBean {

    private List<InventoryRow> items = new ArrayList<InventoryRow>();
    private String searchCategory;
    private String selectedSku;
    private String selectedItemName;
    private String message;

    private String editItemSku;
    private String editItemName;
    private String editCategory;
    private String editUnitType;
    private BigDecimal editParLevel;
    private BigDecimal editCurrentQty;
    private BigDecimal editUnitCost;
    private String editSupplierName;
    private String editSupplierPhone;
    private boolean editing;
    private boolean showForm;

    private static final String DB_URL = "jdbc:oracle:thin:@localhost:1521/ORCLPDB1";
    private static final String DB_USER = "system";
    private static final String DB_PASS = "Oracle123!";

    public InventoryBean() {
        loadAllItems();
    }

    private Connection getConnection() throws SQLException {
        return DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
    }

    private InventoryRow mapRow(ResultSet rs) throws SQLException {
        InventoryRow r = new InventoryRow();
        r.itemSku = rs.getString("item_sku");
        r.itemName = rs.getString("item_name");
        r.category = rs.getString("category");
        r.unitType = rs.getString("unit_type");
        r.parLevel = rs.getBigDecimal("par_level");
        r.currentQty = rs.getBigDecimal("current_qty");
        r.unitCost = rs.getBigDecimal("unit_cost");
        r.supplierName = rs.getString("supplier_name");
        r.supplierPhone = rs.getString("supplier_phone");
        return r;
    }

    public void loadAllItems() {
        items.clear();
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ ? = call PKG_STORE_OPS.get_all_inventory_items }")) {
            cs.registerOutParameter(1, OracleTypes.CURSOR);
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                while (rs.next()) {
                    items.add(mapRow(rs));
                }
            }
            message = null;
        } catch (SQLException e) {
            message = "DB Error: " + e.getMessage();
        }
    }

    public void searchItems(ActionEvent event) {
        selectedSku = null;
        selectedItemName = null;
        if (searchCategory == null || searchCategory.trim().isEmpty()) {
            loadAllItems();
            return;
        }
        items.clear();
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ ? = call PKG_STORE_OPS.find_inventory_by_category(?) }")) {
            cs.registerOutParameter(1, OracleTypes.CURSOR);
            cs.setString(2, searchCategory.trim());
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                while (rs.next()) {
                    items.add(mapRow(rs));
                }
            }
            message = items.isEmpty() ? "No items found in category " + searchCategory : null;
        } catch (SQLException e) {
            message = "Search error: " + e.getMessage();
        }
    }

    public String clearSearch() {
        searchCategory = null;
        selectedSku = null;
        selectedItemName = null;
        message = null;
        loadAllItems();
        return null;
    }

    public String prepareAdd() {
        selectedSku = null;
        selectedItemName = null;
        editItemSku = null;
        editItemName = null;
        editCategory = null;
        editUnitType = null;
        editParLevel = null;
        editCurrentQty = null;
        editUnitCost = null;
        editSupplierName = null;
        editSupplierPhone = null;
        editing = false;
        showForm = true;
        message = null;
        return null;
    }

    public String saveItem() {
        if (editing) {
            return doUpdate();
        }
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ call PKG_STORE_OPS.add_inventory_item(?,?,?,?,?,?,?,?,?) }")) {
            cs.setString(1, editItemSku);
            cs.setString(2, editItemName);
            cs.setString(3, editCategory);
            cs.setString(4, editUnitType);
            cs.setBigDecimal(5, editParLevel);
            cs.setBigDecimal(6, editCurrentQty);
            cs.setBigDecimal(7, editUnitCost);
            cs.setString(8, editSupplierName);
            cs.setString(9, editSupplierPhone);
            cs.execute();
            message = "Inventory item created successfully.";
            loadAllItems();
            showForm = false;
        } catch (SQLException e) {
            message = "Error creating item: " + e.getMessage();
        }
        return null;
    }

    public String prepareEdit() {
        if (selectedSku == null) {
            message = "Select an item first.";
            return null;
        }
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ ? = call PKG_STORE_OPS.get_inventory_item(?) }")) {
            cs.registerOutParameter(1, OracleTypes.CURSOR);
            cs.setString(2, selectedSku);
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                if (rs.next()) {
                    editItemSku = rs.getString("item_sku");
                    editItemName = rs.getString("item_name");
                    editCategory = rs.getString("category");
                    editUnitType = rs.getString("unit_type");
                    editParLevel = rs.getBigDecimal("par_level");
                    editCurrentQty = rs.getBigDecimal("current_qty");
                    editUnitCost = rs.getBigDecimal("unit_cost");
                    editSupplierName = rs.getString("supplier_name");
                    editSupplierPhone = rs.getString("supplier_phone");
                    editing = true;
                    showForm = true;
                }
            }
        } catch (SQLException e) {
            message = "Error loading item: " + e.getMessage();
        }
        return null;
    }

    private String doUpdate() {
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ call PKG_STORE_OPS.update_inventory_item(?,?,?,?,?,?,?,?,?) }")) {
            cs.setString(1, editItemSku);
            cs.setString(2, editItemName);
            cs.setString(3, editCategory);
            cs.setString(4, editUnitType);
            cs.setBigDecimal(5, editParLevel);
            cs.setBigDecimal(6, editCurrentQty);
            cs.setBigDecimal(7, editUnitCost);
            cs.setString(8, editSupplierName);
            cs.setString(9, editSupplierPhone);
            cs.execute();
            message = "Item " + editItemSku + " updated successfully.";
            editing = false;
            showForm = false;
            loadAllItems();
        } catch (SQLException e) {
            message = "Error updating item: " + e.getMessage();
        }
        return null;
    }

    public String deactivateItem() {
        if (selectedSku == null) {
            message = "Select an item first.";
            return null;
        }
        String name = selectedItemName != null ? selectedItemName : selectedSku;
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall("{ call PKG_STORE_OPS.deactivate_inventory_item(?) }")) {
            cs.setString(1, selectedSku);
            cs.execute();
            message = "Item " + name + " deactivated.";
        } catch (SQLException e) {
            message = "Error: " + e.getMessage();
        }
        selectedSku = null;
        selectedItemName = null;
        loadAllItems();
        return null;
    }

    public String selectItem() {
        if (selectedSku != null) {
            for (InventoryRow r : items) {
                if (selectedSku.equals(r.itemSku)) {
                    selectedItemName = r.itemSku + " - " + r.itemName;
                    return null;
                }
            }
        }
        selectedItemName = null;
        return null;
    }

    public String cancelEdit() {
        showForm = false;
        editing = false;
        message = null;
        return null;
    }

    // ---- Getters / Setters ----
    public List<InventoryRow> getItems() { return items; }
    public void setItems(List<InventoryRow> i) { this.items = i; }
    public String getSearchCategory() { return searchCategory; }
    public void setSearchCategory(String s) { this.searchCategory = s; }
    public String getSelectedSku() { return selectedSku; }
    public void setSelectedSku(String s) { this.selectedSku = s; }
    public String getSelectedItemName() { return selectedItemName; }
    public void setSelectedItemName(String s) { this.selectedItemName = s; }
    public String getMessage() { return message; }
    public void setMessage(String s) { this.message = s; }
    public String getEditItemSku() { return editItemSku; }
    public void setEditItemSku(String s) { this.editItemSku = s; }
    public String getEditItemName() { return editItemName; }
    public void setEditItemName(String s) { this.editItemName = s; }
    public String getEditCategory() { return editCategory; }
    public void setEditCategory(String s) { this.editCategory = s; }
    public String getEditUnitType() { return editUnitType; }
    public void setEditUnitType(String s) { this.editUnitType = s; }
    public BigDecimal getEditParLevel() { return editParLevel; }
    public void setEditParLevel(BigDecimal b) { this.editParLevel = b; }
    public BigDecimal getEditCurrentQty() { return editCurrentQty; }
    public void setEditCurrentQty(BigDecimal b) { this.editCurrentQty = b; }
    public BigDecimal getEditUnitCost() { return editUnitCost; }
    public void setEditUnitCost(BigDecimal b) { this.editUnitCost = b; }
    public String getEditSupplierName() { return editSupplierName; }
    public void setEditSupplierName(String s) { this.editSupplierName = s; }
    public String getEditSupplierPhone() { return editSupplierPhone; }
    public void setEditSupplierPhone(String s) { this.editSupplierPhone = s; }
    public boolean isEditing() { return editing; }
    public boolean isShowForm() { return showForm; }

    public static class InventoryRow {
        public String itemSku, itemName, category, unitType;
        public BigDecimal parLevel, currentQty, unitCost;
        public String supplierName, supplierPhone;

        public String getItemSku() { return itemSku; }
        public String getItemName() { return itemName; }
        public String getCategory() { return category; }
        public String getUnitType() { return unitType; }
        public BigDecimal getParLevel() { return parLevel; }
        public BigDecimal getCurrentQty() { return currentQty; }
        public BigDecimal getUnitCost() { return unitCost; }
        public String getSupplierName() { return supplierName; }
        public String getSupplierPhone() { return supplierPhone; }
    }
}
