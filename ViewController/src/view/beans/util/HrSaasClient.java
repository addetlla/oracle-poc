package view.util;

import java.io.IOException;
import java.io.OutputStream;
import java.math.BigDecimal;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.logging.Logger;

public class HrSaasClient {

    private static final Logger LOGGER     = Logger.getLogger(HrSaasClient.class.getName());
    private static final String BASE_URL   = "https://burgerquick.hr.com/api/employee/";
    private static final String API_KEY    = "Xc|bkI_zMXQ{`w8YN5^vb5c#F6YR?4f'$xRy@WUPQ(\"hRy>Pe4";
    private static final int    CONNECT_MS = 3000;
    private static final int    READ_MS    = 3000;

    public static void notifyEmployeeUpdate(
            String employeeId, String firstName, String lastName,
            String position, BigDecimal hourlyRate, String storeNumber) {

        HttpURLConnection conn = null;
        try {
            URL url = new URL(BASE_URL + employeeId + "/update");
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("PUT");
            conn.setConnectTimeout(CONNECT_MS);
            conn.setReadTimeout(READ_MS);
            conn.setDoOutput(true);
            conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
            conn.setRequestProperty("Accept", "application/json");
            conn.setRequestProperty("X-Api-Key", API_KEY);

            String body = buildJson(employeeId, firstName, lastName, position, hourlyRate, storeNumber);
            byte[] bodyBytes = body.getBytes("UTF-8");
            conn.setRequestProperty("Content-Length", String.valueOf(bodyBytes.length));

            try (OutputStream os = conn.getOutputStream()) {
                os.write(bodyBytes);
            }

            int status = conn.getResponseCode();
            if (status < 200 || status >= 300) {
                LOGGER.warning("HR SaaS update failed for employee " + employeeId + ": HTTP " + status);
            }
        } catch (IOException e) {
            LOGGER.warning("HR SaaS update error for employee " + employeeId + ": " + e.getMessage());
        } finally {
            if (conn != null) conn.disconnect();
        }
    }

    private static String buildJson(String id, String firstName, String lastName,
                                    String position, BigDecimal hourlyRate, String storeNumber) {
        return "{"
            + "\"id\":"          + jsonString(id)         + ","
            + "\"firstName\":"   + jsonString(firstName)  + ","
            + "\"lastName\":"    + jsonString(lastName)   + ","
            + "\"position\":"    + jsonString(position)   + ","
            + "\"hourlyRate\":"  + (hourlyRate != null ? hourlyRate.toPlainString() : "null") + ","
            + "\"storeNumber\":" + jsonString(storeNumber)
            + "}";
    }

    private static String jsonString(String v) {
        if (v == null) return "null";
        return "\"" + v.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }
}
