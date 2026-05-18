package model.services;

import oracle.jbo.server.ApplicationModuleImpl;
import oracle.jbo.server.ViewObjectImpl;
import oracle.jbo.server.ViewLinkImpl;
import oracle.jbo.domain.Number;

import model.entities.EmployeeEOImpl;
import model.entities.InventoryItemEOImpl;

/**
 * StoreOps Application Module - THE original business service.
 * Author: Mike Henderson, 2000
 *
 * This AM encapsulates all employee and inventory operations.
 * Every new developer has added their methods here when they
 * couldn't figure out where else to put them.
 *
 * In 2003 Sarah created OrderServiceAM for order stuff (clean separation).
 * In 2006 the offshore team created FranchiseServiceAM (also clean).
 * In 2009 Jason added web order methods HERE instead of in OrderServiceAM
 *   because he "didn't want to mess with Sarah's code."
 * In 2012 the loyalty team added methods HERE too, for the same reason.
 *
 * This AM now has 140+ methods across 5 different functional areas.
 * The original 5 methods Mike wrote are at the top of the file.
 * Good luck finding what you need.
 *
 * - Mike (last updated my section: 2003)
 * - Jason (added web stuff: 2009)
 * - Dmitri (added loyalty integration: 2012)
 * - Dave (added delivery employee lookup: 2020)
 */
public class StoreOpsAMImpl extends ApplicationModuleImpl {

    // ============================================================
    // MIKE'S ORIGINAL METHODS (2000)
    // ============================================================

    /**
     * Find employees by store number. The original employee directory.
     * Still used by the HR page, the POS terminal, the manager dashboard,
     * and the new(ish) mobile app (via a REST wrapper in 2018).
     */
    public ViewObjectImpl findEmployeesByStore(String storeNumber) {
        ViewObjectImpl vo = createViewObject("EmployeeVO");
        vo.setWhereClause("store_number = :storeNum AND is_active = 'Y'");
        vo.defineNamedWhereClauseParam("storeNum", null, null);
        vo.setNamedWhereClauseParam("storeNum", storeNumber);
        vo.executeQuery();
        return vo;
    }

    /**
     * Update inventory quantity.
     *
     * CALL CHAIN WARNING: This method calls the same database procedure
     * (PKG_STORE_OPS.update_inventory) that is called by:
     *   - sp_complete_order (via in-store POS)
     *   - WEB_ORDER_PKG.place_online_order (via web)
     *   - p_MobileOps.placeMobileOrder (via mobile)
     *   - LOYALTY_PKG.inventory_for_reward (via loyalty redemptions)
     *   - SUPPLIER_PKG.receive_inventory_from_supplier (via receiving)
     *
     * If you change the behavior here, you change it for ALL of those.
     * This method exists because some Java code needs to update inventory
     * directly without going through a stored procedure.
     * It's unclear if anything actually calls this from Java anymore.
     *
     * - Mike (original)
     * - Jason (added null check for p_store_no because web orders don't have one)
     */
    public void updateInventory(String sku, Number quantityChange, String storeNo) {
        // Delegate to stored procedure
        // This is a thin wrapper. The real logic is in PL/SQL.
        // Keeping it in PL/SQL was Mike's architectural decision:
        // "The database is the application. Java is just the UI."
        //
        // 20 years later, this philosophy means all business logic
        // lives in PL/SQL packages maintained by 6 different teams.
        try {
            getDBTransaction().executeCommand(
                "BEGIN PKG_STORE_OPS.update_inventory('" + sku + "', " +
                quantityChange + ", '" + (storeNo != null ? storeNo : "NULL") + "'); END;");
        } catch (Exception e) {
            // Swallowing exceptions since 2000.
            // The PL/SQL layer handles its own error logging via AUDIT_LOG.
            // Probably.
            e.printStackTrace();
        }
    }

    // ============================================================
    // JASON'S WEB ORDER METHODS (added 2009)
    // ============================================================
    // Jason: I added these here because I didn't want to create a new AM.
    // Also I wasn't sure how ADF Application Modules work.
    // These should probably be in OrderServiceAM but moving them now
    // would break the JSF pages that reference StoreOpsAM directly.

    /**
     * Look up customer by email for web login.
     *
     * DUPLICATION: p_MobileOps.authenticateUser (Wei, 2012) does the same
     * thing but accesses the CUSTOMERS table directly instead of using this.
     * The mobile app uses theirs. The web app uses this.
     */
    public ViewObjectImpl findCustomerByEmail(String email) {
        ViewObjectImpl vo = createViewObject("CustomerVO");
        vo.setWhereClause("email = :emailAddr AND is_active = 'Y'");
        vo.defineNamedWhereClauseParam("emailAddr", null, null);
        vo.setNamedWhereClauseParam("emailAddr", email);
        vo.executeQuery();
        return vo;
    }

    // ============================================================
    // DMITRI'S LOYALTY METHODS (added 2012)
    // ============================================================
    // Agency team added these. They didn't document what they do.
    // The method names are self-explanatory...ish.

    public void syncLoyaltyPointsForCustomer(Number customerId) {
        // Calls LOYALTY_PKG.nightly_points_recalc for just one customer
        // (which recalculates ALL customers because the proc doesn't
        // take a customer_id parameter. Known issue.)
        try {
            getDBTransaction().executeCommand(
                "BEGIN LOYALTY_PKG.nightly_points_recalc(); END;");
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // ============================================================
    // DAVE'S DELIVERY METHODS (added March 2020)
    // ============================================================
    // Emergency delivery support. Copied the pattern from findEmployeesByStore.
    // Didn't have time to create a separate AM.

    public ViewObjectImpl findAvailableDrivers(String storeNumber) {
        ViewObjectImpl vo = createViewObject("DeliveryDriverVO");
        vo.setWhereClause("is_active_flg = 'Y'");
        vo.executeQuery();
        return vo;
    }
}
