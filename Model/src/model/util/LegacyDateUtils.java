package model.util;

import java.util.Date;
import java.util.Calendar;
import java.text.SimpleDateFormat;

/**
 * Date Utility Methods - Mike Henderson, 2000
 *
 * Written before java.time existed. All of Mike's code uses
 * java.util.Date and these helpers. The entire ADF application
 * is built on these.
 *
 * In 2015 Sarah added DateHelper.java with overlapping methods
 * because she didn't know this class existed (it was in a different
 * package and not documented).
 *
 * In 2020, part of the codebase was updated to use java.time
 * (by an enthusiastic new hire who left after 3 months).
 *
 * So now we have:
 * - LegacyDateUtils (java.util.Date) - used by 80% of the code
 * - DateHelper.java (also java.util.Date, slightly different) - used by 15%
 * - java.time (Java 8+) scattered in newer code - used by 5%
 *
 * All three are in production. Date parsing behavior differs slightly
 * between them. The month-end reports sometimes show dates off by 1 day
 * depending on which utility the report generator happened to use.
 *
 * - Mike (original) + notes from Sarah (2003) + Marcus (2018)
 */
public class LegacyDateUtils {

    // Mike's preferred date format. He liked MM/dd/yyyy because he's American.
    // The European franchisees (added 2006) expect dd/MM/yyyy.
    // The database stores dates correctly but the UI layer sometimes
    // swaps month and day when rendering. See INC-5678, INC-5891, INC-6234.
    private static final SimpleDateFormat DEFAULT_FORMAT = new SimpleDateFormat("MM/dd/yyyy");

    // SimpleDateFormat is NOT thread-safe. Mike didn't know this in 2000.
    // In 2018 Marcus wrapped it in ThreadLocal but only for the new REST code.
    // The existing JSF pages still use the static instance.
    // Under heavy load, date formatting occasionally produces wrong dates.
    // The ops team just refreshes the page when it looks wrong.

    /**
     * Format a date for display. The original date formatter.
     * Still used by: EmployeeDirectory.jspx, InventoryTracker.jspx,
     *   OrderManagement.jspx, FranchiseDashboard.jspx
     */
    public static String formatDate(Date date) {
        if (date == null) return "";
        return DEFAULT_FORMAT.format(date);
    }

    /**
     * Parse a date string. Assumes MM/dd/yyyy format.
     * Throws an unhandled ParseException if the format is wrong.
     * The calling code rarely handles this exception.
     */
    public static Date parseDate(String dateStr) {
        try {
            return DEFAULT_FORMAT.parse(dateStr);
        } catch (Exception e) {
            // Swallow and return null. Callers don't null-check.
            // This causes NullPointerExceptions deep in the UI layer.
            // The error page says "Contact system administrator."
            // The system administrator doesn't know what a NullPointerException is.
            return null;
        }
    }

    /**
     * Get today's date without time component.
     * Used by the daily sales report.
     *
     * IMPORTANT: This truncates to midnight in the JVM's default timezone.
     * The database is in UTC. The stores are in 4 different timezones.
     * "Today" means different things depending on which server processes
     * your request. The BI team accounts for this by running reports
     * at 3am when all stores are closed.
     *
     * DO NOT change this to use java.time. The report generation stored
     * procedures expect java.util.Date via the ADF binding layer.
     * Changing types breaks the ADF model bindings. We tried in 2018.
     * Rolled back after 2 weeks of broken reports.
     */
    public static Date getTodayWithoutTime() {
        Calendar cal = Calendar.getInstance();
        cal.set(Calendar.HOUR_OF_DAY, 0);
        cal.set(Calendar.MINUTE, 0);
        cal.set(Calendar.SECOND, 0);
        cal.set(Calendar.MILLISECOND, 0);
        return cal.getTime();
    }

    /**
     * Calculate days between two dates.
     *
     * DUPLICATION: DateHelper.daysBetween() (Sarah, 2003) does the same thing
     * but uses a different algorithm that rounds differently for fractional days.
     * For dates that are exactly N days apart, both return N.
     * For dates that are N days + some hours apart, this returns N,
     * DateHelper returns N+1. The payroll system uses this one.
     * The franchise royalty calculator uses DateHelper.
     * The discrepancy has caused at least one lawsuit threat from a franchisee.
     */
    public static long daysBetween(Date start, Date end) {
        long diff = end.getTime() - start.getTime();
        return diff / (1000 * 60 * 60 * 24);
    }
}
