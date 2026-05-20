package view.beans;

import java.math.BigDecimal;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

import oracle.jdbc.OracleTypes;

public class FulfillInventoryDeliveryBean {

    private List<DeliveryRow> pendingDeliveries = new ArrayList<DeliveryRow>();
    private List<DeliveryLineItemRow> lineItems = new ArrayList<DeliveryLineItemRow>();

    private BigDecimal selectedDeliveryId;
    private DeliveryRow selectedDelivery;
    private String message;

    private static final String DB_URL = "jdbc:oracle:thin:@localhost:1521/ORCLPDB1";
    private static final String DB_USER = "system";
    private static final String DB_PASS = "Oracle123!";

    public FulfillInventoryDeliveryBean() {
        loadPendingDeliveries();
    }

    private Connection getConnection() throws SQLException {
        return DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
    }

    private DeliveryRow mapDeliveryRow(ResultSet rs) throws SQLException {
        DeliveryRow r = new DeliveryRow();
        r.deliveryId = rs.getBigDecimal("delivery_id");
        r.destinationStoreId = rs.getBigDecimal("destination_store_id");
        r.deliveryAddress = rs.getString("delivery_address");
        r.requestedDate = rs.getDate("requested_date");
        r.notes = rs.getString("notes");
        r.status = rs.getString("status");
        r.createdDate = rs.getDate("created_date");
        r.createdBy = rs.getString("created_by");
        r.storeNumber = rs.getString("store_number");
        r.storeName = rs.getString("store_name");
        r.itemCount = rs.getInt("item_count");
        return r;
    }

    private DeliveryLineItemRow mapLineItemRow(ResultSet rs) throws SQLException {
        DeliveryLineItemRow r = new DeliveryLineItemRow();
        r.lineItemId = rs.getBigDecimal("line_item_id");
        r.itemSku = rs.getString("item_sku");
        r.quantity = rs.getBigDecimal("quantity");
        r.unitCost = rs.getBigDecimal("unit_cost");
        r.itemName = rs.getString("item_name");
        r.unitType = rs.getString("unit_type");
        r.currentInventoryQty = rs.getBigDecimal("current_inventory_qty");
        return r;
    }

    public void loadPendingDeliveries() {
        pendingDeliveries.clear();
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall(
                 "{ ? = call DELIVERY_ENHANCEMENT_PKG.get_pending_deliveries }")) {
            cs.registerOutParameter(1, OracleTypes.CURSOR);
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                while (rs.next()) {
                    pendingDeliveries.add(mapDeliveryRow(rs));
                }
            }
            message = null;
        } catch (SQLException e) {
            message = "Error loading queue: " + e.getMessage();
        }
    }

    public String selectDelivery() {
        if (selectedDeliveryId == null) {
            return null;
        }
        selectedDelivery = null;
        for (DeliveryRow r : pendingDeliveries) {
            if (r.deliveryId.equals(selectedDeliveryId)) {
                selectedDelivery = r;
                break;
            }
        }
        loadLineItems();
        return null;
    }

    private void loadLineItems() {
        lineItems.clear();
        if (selectedDelivery == null) return;

        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall(
                 "{ ? = call DELIVERY_ENHANCEMENT_PKG.get_delivery_items(?) }")) {
            cs.registerOutParameter(1, OracleTypes.CURSOR);
            cs.setBigDecimal(2, selectedDeliveryId);
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                while (rs.next()) {
                    lineItems.add(mapLineItemRow(rs));
                }
            }
        } catch (SQLException e) {
            message = "Error loading line items: " + e.getMessage();
        }
    }

    public String fulfillDelivery() {
        if (selectedDeliveryId == null) {
            message = "Select a delivery first.";
            return null;
        }

        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall(
                 "{ call DELIVERY_ENHANCEMENT_PKG.fulfill_inventory_delivery(?,?) }")) {
            cs.setBigDecimal(1, selectedDeliveryId);
            cs.setString(2, "SYSTEM");
            cs.execute();
            message = "Delivery #" + selectedDeliveryId + " fulfilled. Inventory updated.";

            selectedDeliveryId = null;
            selectedDelivery = null;
            lineItems.clear();
            loadPendingDeliveries();

        } catch (SQLException e) {
            message = "Error fulfilling delivery: " + e.getMessage();
        }
        return null;
    }

    public String cancelDelivery() {
        if (selectedDeliveryId == null) {
            message = "Select a delivery first.";
            return null;
        }

        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall(
                 "{ call DELIVERY_ENHANCEMENT_PKG.cancel_inventory_delivery(?,?) }")) {
            cs.setBigDecimal(1, selectedDeliveryId);
            cs.setString(2, "Cancelled by user");
            cs.execute();
            message = "Delivery #" + selectedDeliveryId + " cancelled.";

            selectedDeliveryId = null;
            selectedDelivery = null;
            lineItems.clear();
            loadPendingDeliveries();

        } catch (SQLException e) {
            message = "Error cancelling delivery: " + e.getMessage();
        }
        return null;
    }

    // ---- Getters / Setters ----

    public List<DeliveryRow> getPendingDeliveries() { return pendingDeliveries; }
    public List<DeliveryLineItemRow> getLineItems() { return lineItems; }

    public BigDecimal getSelectedDeliveryId() { return selectedDeliveryId; }
    public void setSelectedDeliveryId(BigDecimal id) { this.selectedDeliveryId = id; }

    public DeliveryRow getSelectedDelivery() { return selectedDelivery; }

    public String getMessage() { return message; }
    public void setMessage(String msg) { this.message = msg; }

    // ---- Inner Classes (public static for EL access) ----

    public static class DeliveryRow {
        public BigDecimal deliveryId;
        public BigDecimal destinationStoreId;
        public String deliveryAddress;
        public Date requestedDate;
        public String notes;
        public String status;
        public Date createdDate;
        public String createdBy;
        public String storeNumber;
        public String storeName;
        public int itemCount;

        public BigDecimal getDeliveryId() { return deliveryId; }
        public BigDecimal getDestinationStoreId() { return destinationStoreId; }
        public String getDeliveryAddress() { return deliveryAddress; }
        public Date getRequestedDate() { return requestedDate; }
        public String getNotes() { return notes; }
        public String getStatus() { return status; }
        public Date getCreatedDate() { return createdDate; }
        public String getCreatedBy() { return createdBy; }
        public String getStoreNumber() { return storeNumber; }
        public String getStoreName() { return storeName; }
        public int getItemCount() { return itemCount; }

        public String getStoreLabel() {
            return storeNumber + " - " + storeName;
        }
    }

    public static class DeliveryLineItemRow {
        public BigDecimal lineItemId;
        public String itemSku;
        public BigDecimal quantity;
        public BigDecimal unitCost;
        public String itemName;
        public String unitType;
        public BigDecimal currentInventoryQty;

        public BigDecimal getLineItemId() { return lineItemId; }
        public String getItemSku() { return itemSku; }
        public BigDecimal getQuantity() { return quantity; }
        public BigDecimal getUnitCost() { return unitCost; }
        public String getItemName() { return itemName; }
        public String getUnitType() { return unitType; }
        public BigDecimal getCurrentInventoryQty() { return currentInventoryQty; }
    }
}
