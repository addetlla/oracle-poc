package view.beans;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

public class DashboardBean {

    private int pendingDeliveriesCount;
    private int fulfilledTodayCount;
    private String message;

    private static final String DB_URL = "jdbc:oracle:thin:@localhost:1521/ORCLPDB1";
    private static final String DB_USER = "system";
    private static final String DB_PASS = "Oracle123!";

    public DashboardBean() {
        loadDashboardStats();
    }

    private Connection getConnection() throws SQLException {
        return DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
    }

    public void loadDashboardStats() {
        try (Connection conn = getConnection();
             Statement stmt = conn.createStatement()) {

            try (ResultSet rs = stmt.executeQuery(
                     "SELECT COUNT(*) FROM INVENTORY_DELIVERIES WHERE status = 'PENDING'")) {
                if (rs.next()) pendingDeliveriesCount = rs.getInt(1);
            }

            try (ResultSet rs = stmt.executeQuery(
                     "SELECT COUNT(*) FROM INVENTORY_DELIVERIES WHERE status = 'COMPLETED' AND TRUNC(fulfilled_date) = TRUNC(SYSDATE)")) {
                if (rs.next()) fulfilledTodayCount = rs.getInt(1);
            }

            message = null;
        } catch (SQLException e) {
            message = "Error loading stats: " + e.getMessage();
        }
    }

    public void handlePoll(org.apache.myfaces.trinidad.event.PollEvent pollEvent) {
        loadDashboardStats();
    }

    public int getPendingDeliveriesCount() { return pendingDeliveriesCount; }
    public int getFulfilledTodayCount() { return fulfilledTodayCount; }
    public String getMessage() { return message; }
}
