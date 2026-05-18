package view.beans;

import java.util.ArrayList;
import java.util.List;

/**
 * Employee Directory Managed Bean - Mike Henderson, 2000
 *
 * The very first managed bean in BurgerQuick. Request-scoped,
 * no dependency injection, basic JSF binding. This pattern was
 * considered "modern" in 2000 because it wasn't a servlet.
 *
 * Mike learned JSF from the early access draft spec.
 * It shows. No validation, no error handling, no navigation cases.
 * Just a simple bean that reads from the database and displays a table.
 *
 * EVERY subsequent developer has copied this bean for their own pages.
 * The pattern is baked into the entire codebase:
 *   - OrderBean (Sarah, 2003) - copied this, added session scope
 *   - FranchiseDashboardBean (Raj, 2006) - copied OrderBean
 *   - OnlineOrderBean (Jason, 2009) - copied FranchiseDashboardBean
 *   - LoyaltyBean (Wei, 2012) - copied OnlineOrderBean
 *   - DeliveryTrackerBean (Dave, 2020) - copied LoyaltyBean
 *
 * Each copy added features but nobody refactored the base pattern.
 * Now there are 6 beans with 80% duplicated structure and 20% divergent logic.
 *
 * - Mike
 */
public class EmployeeBean {

    // Mike's approach: store everything in lists. No service layer.
    // The ADF binding layer handles the database interaction.
    // If the binding breaks, the page shows "No data found" with no clue why.

    private List<Object> employees = new ArrayList<>();
    private String searchStoreNumber;    // Filter by store
    private String selectedEmployeeId;   // Currently selected employee
    private String message;              // Status message (rarely set)

    // Mike used String for store number. Sarah used int for store ID in OrderBean.
    // The store_number in EMPLOYEES is VARCHAR2(5). The store_id in STORES is NUMBER.
    // These don't directly join without a conversion. See INC-1234.

    public String searchEmployees() {
        // Binds to ADF iterator that calls PKG_STORE_OPS.find_employees_by_store
        // The binding is defined in the page definition XML.
        // If the page definition is wrong, this silently fails.
        employees.clear();
        // In a real ADF app: RichBindingContainer bindings = getBindings();
        // DCIteratorBinding iter = bindings.findIteratorBinding("EmployeeIterator");
        // iter.getViewObject().setNamedWhereClauseParam("storeNum", searchStoreNumber);
        // iter.executeQuery();
        return null; // Stay on same page
    }

    public String selectEmployee() {
        // Navigate to employee detail page
        // Mike used hardcoded navigation strings. The navigation rules are
        // in faces-config.xml, added by Sarah in 2003 because Mike's version
        // didn't have any navigation.
        return "employeeDetail";
    }

    // Standard getters/setters (no JavaDoc - Mike was the only dev in 2000,
    // documentation was "ask Mike")
    public List<Object> getEmployees() { return employees; }
    public void setEmployees(List<Object> employees) { this.employees = employees; }
    public String getSearchStoreNumber() { return searchStoreNumber; }
    public void setSearchStoreNumber(String searchStoreNumber) { this.searchStoreNumber = searchStoreNumber; }
    public String getSelectedEmployeeId() { return selectedEmployeeId; }
    public void setSelectedEmployeeId(String selectedEmployeeId) { this.selectedEmployeeId = selectedEmployeeId; }
    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
}
