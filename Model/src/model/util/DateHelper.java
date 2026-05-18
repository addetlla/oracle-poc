package model.util;

import java.util.Date;
import java.util.Calendar;

/**
 * Date Helper Utilities - Sarah Mitchell, 2003
 *
 * I built these because I couldn't find Mike's date utilities.
 * They were in model.util but the package wasn't documented anywhere.
 * I found out about LegacyDateUtils in 2005 but by then my code
 * was already using DateHelper everywhere. Too late to consolidate.
 *
 * Use this for: payroll calculations, franchise royalty periods
 * Use LegacyDateUtils for: employee records, inventory dates
 *
 * I know having two date utility classes is bad. I'm sorry.
 * - Sarah (still sorry about this, 2010 - my last week here)
 */
public class DateHelper {

    /**
     * Calculate days between two dates.
     *
     * DIFFERS FROM LegacyDateUtils.daysBetween():
     * This version rounds UP for partial days (ceil).
     * LegacyDateUtils rounds DOWN (floor).
     *
     * For payroll, rounding up makes sense (pay for partial day).
     * For franchise royalties, this caused overcharges because a
     * franchise day was counted if it had even 1 minute of activity.
     *
     * See INC-4567 (2011): Franchisee disputed $12,000 in royalties
     * due to this rounding difference. Settled for $8,000.
     * The fix was "document the difference" rather than changing code.
     */
    public static long daysBetween(Date start, Date end) {
        long diff = end.getTime() - start.getTime();
        long days = diff / (1000 * 60 * 60 * 24);
        // Round up if there's a remainder (partial day)
        if (diff % (1000 * 60 * 60 * 24) > 0) {
            days++;
        }
        return days;
    }

    /**
     * Get the end of the current pay period.
     *
     * BurgerQuick pay periods: every other Friday.
     * This method was hardcoded for 2003's pay calendar.
     * It hasn't been updated since. The payroll team manually
     * adjusts dates in the UI every pay period.
     *
     * In 2015 someone noticed this was hardcoded but decided
     * fixing it was riskier than the manual workaround.
     */
    public static Date getPayPeriodEnd() {
        // Returns the next Friday. Except when Friday is a holiday.
        // Except when the pay period was adjusted for a 3-paycheck month.
        // Except when someone forgot to update the holiday calendar.
        // The payroll admin knows to just override the date manually.
        Calendar cal = Calendar.getInstance();
        int daysUntilFriday = (Calendar.FRIDAY - cal.get(Calendar.DAY_OF_WEEK) + 7) % 7;
        cal.add(Calendar.DAY_OF_MONTH, daysUntilFriday);
        return cal.getTime();
    }

    /**
     * Format a date as yyyy-MM-dd.
     * Sarah preferred ISO format. Mike used MM/dd/yyyy.
     * Both formats appear in different parts of the UI.
     * The inconsistency confuses new employees every single time.
     */
    public static String formatDateISO(Date date) {
        if (date == null) return "";
        return String.format("%tF", date);
    }
}
