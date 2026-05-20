package view.beans;

import java.math.BigDecimal;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

import oracle.jdbc.OracleTypes;

public class CreateInventoryDeliveryBean {

    private List<javax.faces.model.SelectItem> stores = new ArrayList<javax.faces.model.SelectItem>();
    private List<javax.faces.model.SelectItem> inventoryItems = new ArrayList<javax.faces.model.SelectItem>();
    private List<InventoryItemOption> rawInventoryItems = new ArrayList<InventoryItemOption>();
    private List<DeliveryLineItem> cart = new ArrayList<DeliveryLineItem>();

    private BigDecimal selectedStoreId;
    private String selectedSku;
    private BigDecimal quantityToAdd;

    private String deliveryAddress;
    private String requestedDate;
    private String notes;
    private String message;
    private boolean submitted;

    private static final String DB_URL = "jdbc:oracle:thin:@localhost:1521/ORCLPDB1";
    private static final String DB_USER = "system";
    private static final String DB_PASS = "Oracle123!";

    public CreateInventoryDeliveryBean() {
        loadDropdowns();
    }

    private Connection getConnection() throws SQLException {
        return DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
    }

    private StoreOption mapStoreRow(ResultSet rs) throws SQLException {
        StoreOption s = new StoreOption();
        s.storeId = rs.getBigDecimal("store_id");
        s.storeNumber = rs.getString("store_number");
        s.storeName = rs.getString("store_name");
        s.city = rs.getString("city");
        s.state = rs.getString("state");
        return s;
    }

    private InventoryItemOption mapItemRow(ResultSet rs) throws SQLException {
        InventoryItemOption i = new InventoryItemOption();
        i.itemSku = rs.getString("item_sku");
        i.itemName = rs.getString("item_name");
        i.unitType = rs.getString("unit_type");
        i.currentQty = rs.getBigDecimal("current_qty");
        return i;
    }

    public void loadDropdowns() {
        stores.clear();
        inventoryItems.clear();
        rawInventoryItems.clear();
        try (Connection conn = getConnection()) {

            // Load stores
            try (CallableStatement cs = conn.prepareCall(
                    "{ ? = call DELIVERY_ENHANCEMENT_PKG.get_all_stores }")) {
                cs.registerOutParameter(1, OracleTypes.CURSOR);
                cs.execute();
                try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                    while (rs.next()) {
                        StoreOption s = mapStoreRow(rs);
                        stores.add(new javax.faces.model.SelectItem(s.getStoreId(), s.getLabel()));
                    }
                }
            }

            // Load inventory items
            try (CallableStatement cs = conn.prepareCall(
                    "{ ? = call DELIVERY_ENHANCEMENT_PKG.get_active_inventory_items }")) {
                cs.registerOutParameter(1, OracleTypes.CURSOR);
                cs.execute();
                try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                    while (rs.next()) {
                        InventoryItemOption i = mapItemRow(rs);
                        rawInventoryItems.add(i);
                        inventoryItems.add(new javax.faces.model.SelectItem(i.getItemSku(), i.getLabel()));
                    }
                }
            }

        } catch (SQLException e) {
            message = "Error loading dropdowns: " + e.getMessage();
        }
    }

    public String addLineItem() {
        submitted = false;
        if (selectedSku == null || selectedSku.trim().isEmpty()) {
            message = "Select an inventory item first.";
            return null;
        }
        if (quantityToAdd == null || quantityToAdd.compareTo(BigDecimal.ZERO) <= 0) {
            message = "Quantity must be greater than 0.";
            return null;
        }

        // Find the item name for the selected SKU
        String itemName = selectedSku;
        for (InventoryItemOption item : rawInventoryItems) {
            if (item.itemSku.equals(selectedSku)) {
                itemName = item.itemName;
                break;
            }
        }

        // If SKU already in cart, add to existing quantity
        for (DeliveryLineItem existing : cart) {
            if (existing.itemSku.equals(selectedSku)) {
                existing.quantity = existing.quantity.add(quantityToAdd);
                message = "Updated " + itemName + " quantity to " + existing.quantity + ".";
                selectedSku = null;
                quantityToAdd = null;
                return null;
            }
        }

        DeliveryLineItem line = new DeliveryLineItem();
        line.itemSku = selectedSku;
        line.itemName = itemName;
        line.quantity = quantityToAdd;
        cart.add(line);

        message = "Added " + itemName + " (qty: " + quantityToAdd + ") to delivery.";
        selectedSku = null;
        quantityToAdd = null;
        return null;
    }

    public String removeLineItem() {
        submitted = false;
        if (selectedSku != null) {
            cart.removeIf(item -> item.itemSku.equals(selectedSku));
            message = "Removed item from delivery.";
            selectedSku = null;
        }
        return null;
    }

    public String submitDelivery() {
        submitted = false;
        if (selectedStoreId == null) {
            message = "Select a destination store.";
            return null;
        }
        if (cart.isEmpty()) {
            message = "Add at least one inventory item.";
            return null;
        }
        if (deliveryAddress == null || deliveryAddress.trim().isEmpty()) {
            message = "Enter a delivery address.";
            return null;
        }

        // Build items string: 'SKU1:QTY1;SKU2:QTY2;...'
        StringBuilder items = new StringBuilder();
        for (int i = 0; i < cart.size(); i++) {
            if (i > 0) items.append(";");
            DeliveryLineItem line = cart.get(i);
            items.append(line.itemSku).append(":").append(line.quantity);
        }

        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall(
                 "{ call DELIVERY_ENHANCEMENT_PKG.create_inventory_delivery(?,?,?,?,?,?) }")) {
            cs.setBigDecimal(1, selectedStoreId);
            cs.setString(2, deliveryAddress.trim());
            cs.setString(3, requestedDate != null ? requestedDate.trim() : null);
            cs.setString(4, notes != null ? notes.trim() : null);
            cs.setString(5, items.toString());
            cs.registerOutParameter(6, Types.NUMERIC);
            cs.execute();

            BigDecimal deliveryId = cs.getBigDecimal(6);
            message = "Delivery #" + deliveryId + " created with " + cart.size() + " item(s).";
            submitted = true;

            // Clear form fields but keep success message + submitted flag
            selectedStoreId = null;
            selectedSku = null;
            quantityToAdd = null;
            deliveryAddress = null;
            requestedDate = null;
            notes = null;
            cart.clear();

        } catch (SQLException e) {
            message = "Error creating delivery: " + e.getMessage();
            submitted = false;
        }
        return null;
    }

    public String resetForm() {
        selectedStoreId = null;
        selectedSku = null;
        quantityToAdd = null;
        deliveryAddress = null;
        requestedDate = null;
        notes = null;
        message = null;
        submitted = false;
        cart.clear();
        // Redirect to self for a clean GET — clears stale submitted values
        // that survive when immediate="true" skips the Update Model phase.
        try {
            javax.faces.context.FacesContext.getCurrentInstance()
                .getExternalContext().redirect("createInventoryDelivery.jspx");
        } catch (java.io.IOException e) {
            // Fall through — return null to stay on page
        }
        return null;
    }

    // ---- Getters / Setters ----

    public List<javax.faces.model.SelectItem> getStores() { return stores; }
    public List<javax.faces.model.SelectItem> getInventoryItems() { return inventoryItems; }
    public List<DeliveryLineItem> getCart() { return cart; }

    public BigDecimal getSelectedStoreId() { return selectedStoreId; }
    public void setSelectedStoreId(BigDecimal id) { this.selectedStoreId = id; }

    public String getSelectedSku() { return selectedSku; }
    public void setSelectedSku(String sku) { this.selectedSku = sku; }

    public BigDecimal getQuantityToAdd() { return quantityToAdd; }
    public void setQuantityToAdd(BigDecimal qty) { this.quantityToAdd = qty; }

    public String getDeliveryAddress() { return deliveryAddress; }
    public void setDeliveryAddress(String addr) { this.deliveryAddress = addr; }

    public String getRequestedDate() { return requestedDate; }
    public void setRequestedDate(String date) { this.requestedDate = date; }

    public String getNotes() { return notes; }
    public void setNotes(String n) { this.notes = n; }

    public String getMessage() { return message; }
    public void setMessage(String msg) { this.message = msg; }

    public boolean isSubmitted() { return submitted; }

    // ---- Inner Classes (public static for EL access) ----

    public static class StoreOption {
        public BigDecimal storeId;
        public String storeNumber;
        public String storeName;
        public String city;
        public String state;

        public BigDecimal getStoreId() { return storeId; }
        public String getStoreNumber() { return storeNumber; }
        public String getStoreName() { return storeName; }
        public String getCity() { return city; }
        public String getState() { return state; }

        public String getLabel() {
            return storeNumber + " - " + storeName + " (" + city + ")";
        }
    }

    public static class InventoryItemOption {
        public String itemSku;
        public String itemName;
        public String unitType;
        public BigDecimal currentQty;

        public String getItemSku() { return itemSku; }
        public String getItemName() { return itemName; }
        public String getUnitType() { return unitType; }
        public BigDecimal getCurrentQty() { return currentQty; }

        public String getLabel() {
            return itemSku + " - " + itemName + " (" + unitType + ")";
        }
    }

    public static class DeliveryLineItem {
        public String itemSku;
        public String itemName;
        public BigDecimal quantity;

        public String getItemSku() { return itemSku; }
        public String getItemName() { return itemName; }
        public BigDecimal getQuantity() { return quantity; }
    }
}
