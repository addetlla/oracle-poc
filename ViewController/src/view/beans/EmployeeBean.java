package view.beans;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

import javax.faces.event.ActionEvent;

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

    private List<EmployeeRow> employees = new ArrayList<EmployeeRow>();
    private String searchStoreNumber;
    private String selectedEmployeeId;
    private String message;

    // Pre-loaded sample data for demo (in production, this comes from
    // the ADF iterator binding calling PKG_STORE_OPS.find_employees_by_store)
    private static final Object[][] SAMPLE_DATA = {
        {"BQ-EMP-0001", "Mike", "Henderson", "Store Manager", new BigDecimal("18.50")},
        {"BQ-EMP-0002", "Tom", "Reynolds", "Shift Lead", new BigDecimal("12.00")},
        {"BQ-EMP-0003", "Lisa", "Chen", "Cashier", new BigDecimal("8.50")},
        {"BQ-EMP-0004", "James", "Washington", "Cook", new BigDecimal("9.00")},
        {"BQ-EMP-0005", "Maria", "Garcia", "Cashier", new BigDecimal("8.50")},
    };

    public EmployeeBean() {
        for (Object[] row : SAMPLE_DATA) {
            EmployeeRow er = new EmployeeRow();
            er.employeeId = (String) row[0];
            er.firstName = (String) row[1];
            er.lastName = (String) row[2];
            er.position = (String) row[3];
            er.hourlyRate = (BigDecimal) row[4];
            employees.add(er);
        }
    }

    public void searchEmployees(ActionEvent event) {
        // In production, this would call the ADF iterator binding
        message = "Showing all employees (DB binding not configured for PoC)";
    }

    public String selectEmployee() {
        return null; // Stay on same page for PoC
    }

    public List<EmployeeRow> getEmployees() { return employees; }
    public void setEmployees(List<EmployeeRow> employees) { this.employees = employees; }
    public String getSearchStoreNumber() { return searchStoreNumber; }
    public void setSearchStoreNumber(String searchStoreNumber) { this.searchStoreNumber = searchStoreNumber; }
    public String getSelectedEmployeeId() { return selectedEmployeeId; }
    public void setSelectedEmployeeId(String selectedEmployeeId) { this.selectedEmployeeId = selectedEmployeeId; }
    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    /**
     * Inner row class. In production ADF, this would be the ViewObject row.
     * Mike didn't know about inner classes so the original was a separate file.
     * We kept it inner for the PoC.
     */
    public static class EmployeeRow {
        public String employeeId;
        public String firstName;
        public String lastName;
        public String position;
        public BigDecimal hourlyRate;

        public String getEmployeeId() { return employeeId; }
        public String getFirstName() { return firstName; }
        public String getLastName() { return lastName; }
        public String getPosition() { return position; }
        public BigDecimal getHourlyRate() { return hourlyRate; }
    }
}
