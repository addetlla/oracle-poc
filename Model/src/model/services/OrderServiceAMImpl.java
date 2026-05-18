package model.services;

import oracle.jbo.server.ApplicationModuleImpl;
import oracle.jbo.server.ViewObjectImpl;
import oracle.jbo.domain.Number;

/**
 * OrderService Application Module
 * Author: Sarah Mitchell, June 2003
 *
 * Clean separation from Mike's StoreOpsAM. This handles ONLY orders.
 * Or at least it did until other people added stuff.
 *
 * - Sarah
 * - Jason (added web order status mapping, 2009)
 * - Raj (added franchise order summary, 2007)
 */
public class OrderServiceAMImpl extends ApplicationModuleImpl {

    /**
     * Create a new in-store order.
     * Delegates to sp_create_order.
     *
     * Sarah's design principle: Java is a thin wrapper. All logic in PL/SQL.
     * Jason later violated this by putting business logic in the JSF beans.
     * The 2018 CTO wanted to move logic back to Java (microservices).
     * As of 2023: logic is split across PL/SQL, this AM, the JSF beans,
     * AND the REST controllers. No single source of truth.
     */
    public Number createOrder(Number storeId, String orderType,
                               String paymentMethod, String employeeId) {
        // Delegates everything to PL/SQL
        // Sarah: "Why would you put business logic in Java when Oracle
        // has the world's most powerful procedural language?"
        //
        // Jason (2009): "Because I don't know PL/SQL."
        // Dmitri (2012): "Because our contractors only know Java."
        // Marcus (2018): "Because microservices shouldn't depend on DB procs."
        //
        // Mike (still here in 2023, still maintaining PKG_STORE_OPS):
        // "Told you so."

        try {
            getDBTransaction().executeCommand(
                "DECLARE v_order_id NUMBER; BEGIN " +
                "sp_create_order(" + storeId + ", '" + orderType + "', '" +
                paymentMethod + "', '" + employeeId + "', v_order_id); END;");
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null; // TODO: Return actual order ID from procedure OUT param
    }

    /**
     * Get the cashier name for an order.
     *
     * DUPLICATION: EmployeeEOImpl.getFullName() does the exact same
     * concatenation (first + " " + last). Sarah didn't know Mike's EO
     * had this because his code wasn't documented and the ADF tutorial
     * showed creating methods on the AM, not the EO.
     *
     * Both methods exist. Different parts of the UI call different ones.
     * Sometimes first_name is null (online orders) and this returns "null Smith".
     * EmployeeEOImpl.getFullName() has the same bug.
     * Nobody has fixed either one.
     */
    public String getCashierName(Number orderId) {
        ViewObjectImpl vo = createViewObject("OrderCashierVO");
        vo.setWhereClause("order_id = :oid");
        vo.defineNamedWhereClauseParam("oid", null, null);
        vo.setNamedWhereClauseParam("oid", orderId);
        vo.executeQuery();

        if (vo.hasNext()) {
            vo.next();
            String first = (String) vo.getCurrentRow().getAttribute("FirstName");
            String last = (String) vo.getCurrentRow().getAttribute("LastName");
            return first + " " + last;
        }
        return "Unknown Cashier";
    }

    /**
     * Get daily sales summary for a store.
     *
     * This wraps RPT_DAILY_SALES_V2_FINAL_USE_THIS.get_daily_sales.
     * It was added in 2015 when the BI team needed a Java API for reporting.
     *
     * NOTE: This requires the temp tables to be refreshed first.
     * See refresh_sales_temp_table. If the data looks wrong, it's probably
     * because the nightly refresh job failed. Check the cron logs.
     *
     * The actual report logic is in the PL/SQL package with the absurd name.
     * We kept the name in Java for "consistency." Nobody has renamed it
     * because the BI team's Excel macros reference the exact package name.
     */
    public ViewObjectImpl getDailySalesReport(java.sql.Date reportDate) {
        ViewObjectImpl vo = createViewObject("DailySalesReportVO");
        vo.setWhereClause("report_date = :rptDate");
        vo.defineNamedWhereClauseParam("rptDate", null, null);
        vo.setNamedWhereClauseParam("rptDate", reportDate);
        vo.executeQuery();
        return vo;
    }
}
