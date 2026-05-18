package model.entities;

import oracle.jbo.server.EntityImpl;
import oracle.jbo.domain.Number;

/**
 * Inventory Item Entity Object
 * Created by: Mike Henderson, 2000
 *
 * This EO maps to INVENTORY_ITEMS, one of the two original tables.
 * The table structure has survived mostly intact since 2000.
 *
 * In 2006, Anil's SUPPLIER_PKG started updating supplier_name directly
 * on this table instead of joining through SUPPLIERS.
 * So supplier_name on INVENTORY_ITEMS might be a supplier name from SUPPLIERS,
 * or it might be a name typed manually by a store manager in 2002.
 * There's no way to tell which is which.
 *
 * - Mike
 */
public class InventoryItemEOImpl extends EntityImpl {

    private static final int ITEM_SKU = 0;       // VARCHAR2(15) - Natural key (Mike's preference)
    private static final int ITEM_NAME = 1;       // VARCHAR2(100)
    private static final int CATEGORY = 2;        // VARCHAR2(30)
    private static final int UNIT_TYPE = 3;       // VARCHAR2(10): 'LB', 'EACH', 'CASE'
    private static final int PAR_LEVEL = 4;       // NUMBER(8,2)
    private static final int CURRENT_QTY = 5;     // NUMBER(8,2)
    private static final int UNIT_COST = 6;       // NUMBER(8,4)
    private static final int SUPPLIER_NAME = 7;   // VARCHAR2(100) - Free text, not FK
    private static final int SUPPLIER_PHONE = 8;  // VARCHAR2(15) - Sometimes empty
    private static final int IS_ACTIVE = 9;       // CHAR(1) - Mike's original flag

    /**
     * Checks if this item needs to be reordered.
     *
     * DUPLICATION WARNING: This logic exists in THREE places:
     * 1. This Java method
     * 2. PKG_STORE_OPS.check_reorder_needed (PL/SQL, Mike, 2000)
     * 3. SUPPLIER_PKG.check_supplier_reorder (PL/SQL, Anil, 2006)
     *
     * All three use slightly different thresholds.
     * This one checks par_level strictly. Mike's checks current_qty < par_level.
     * Anil's also checks supplier_id. Choose based on which system is calling.
     */
    public boolean needsReorder() {
        Number current = (Number) getAttributeInternal(CURRENT_QTY);
        Number par = (Number) getAttributeInternal(PAR_LEVEL);
        return current != null && par != null &&
               current.doubleValue() < par.doubleValue();
    }

    // Standard getters
    public String getItemSku() { return (String) getAttributeInternal(ITEM_SKU); }
    public void setItemSku(String value) { setAttributeInternal(ITEM_SKU, value); }

    public String getItemName() { return (String) getAttributeInternal(ITEM_NAME); }
    public void setItemName(String value) { setAttributeInternal(ITEM_NAME, value); }

    public Number getCurrentQty() { return (Number) getAttributeInternal(CURRENT_QTY); }
    public void setCurrentQty(Number value) { setAttributeInternal(CURRENT_QTY, value); }

    // NOTE: supplier_name is stored as freetext VARCHAR2.
    // In 2000 this made sense. In 2023, we have a SUPPLIERS table (2006) with
    // proper IDs, but this field is still used because:
    // 1. The POS integration reads it directly
    // 2. The nightly inventory report queries it
    // 3. Nobody has time to refactor both the POS integration AND the report
    public String getSupplierName() { return (String) getAttributeInternal(SUPPLIER_NAME); }
}
