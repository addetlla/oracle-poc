package model.rest;

// ============================================================
// OrderRestController - CTO's Modernization Project (2018)
// Author: Marcus Chen, March 2018
// ============================================================
// The CTO wanted REST APIs for everything. This was Phase 1.
// Phase 2 (split into microservices) was cancelled when Kevin left.
//
// This controller wraps the legacy PL/SQL packages through
// the ADF Application Modules. It's a REST facade over:
//   - StoreOpsAMImpl (Mike, 2000)
//   - OrderServiceAMImpl (Sarah, 2003)
//   - FranchiseServiceAMImpl (Raj, 2006)
//   - WEB_ORDER_PKG (Jason, 2009 - called via PL/SQL)
//   - LOYALTY_PKG (Dmitri, 2012 - called via PL/SQL)
//   - DELIVERY_PKG (Dave, 2020 - called via PL/SQL)
//
// All of which ultimately funnel into PKG_STORE_OPS.update_inventory (Mike, 2000).
//
// If a REST call fails, trace it through AT LEAST 4 layers of delegation
// before you find the actual error.
//
// - Marcus (left the company, August 2018)
// - Maintained by: Nobody specifically. Whoever touches orders.
// ============================================================

// NOTE: This was written for JAX-RS but the project dependencies were
// never fully configured. The CTO's departure meant nobody finished
// setting up the REST infrastructure.
//
// The class is here, it compiles, but the endpoints might not be reachable
// depending on which WebLogic version you're on and whether anyone
// remembered to add the JAX-RS library to the deployment.
//
// - Marcus, June 2018

import javax.ws.rs.*;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import java.util.HashMap;
import java.util.Map;

@Path("/api/orders")
public class OrderRestController {

    /**
     * Create an order via REST API.
     *
     * This is the "modern" way to create orders. It wraps the same
     * legacy stored procedures everything else uses.
     *
     * Supported order sources:
     * - "WEB": routes through WEB_ORDER_PKG.place_online_order
     * - "MOBILE": routes through p_MobileOps.placeMobileOrder
     * - "POS": routes through sp_create_order directly
     *
     * The source parameter was supposed to let us gradually migrate
     * all order sources to this single REST endpoint. But:
     * - The web team never migrated (their JSF pages work fine)
     * - The mobile team partially migrated (Android uses this, iOS doesn't)
     * - The POS terminals can't make HTTP calls (they're on a private network)
     *
     * So this endpoint only handles new mobile app orders. 80% of orders
     * still go through the old paths.
     */
    @POST
    @Path("/create")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response createOrder(Map<String, Object> orderRequest) {
        Map<String, Object> response = new HashMap<>();

        try {
            // Extract parameters from JSON
            Number customerId = (Number) orderRequest.get("customerId");
            Number storeId = (Number) orderRequest.get("storeId");
            String items = (String) orderRequest.get("items");  // JSON string
            String paymentToken = (String) orderRequest.get("paymentToken");

            // Delegate to API_ORDER_SERVICE wrapper (which delegates to
            // WEB_ORDER_PKG, which delegates to sp_complete_order, which
            // calls PKG_STORE_OPS.update_inventory).
            //
            // Yes, this is a 5-layer call stack for what could be an INSERT.
            // But each layer was added with good intentions at the time.
            // - Marcus, 2018

            // TODO: Actually call the PL/SQL. This was supposed to be
            // implemented after the JAX-RS library was properly configured.
            // The JAX-RS library was never properly configured.
            // Using placeholder response until infrastructure is ready.
            // - Marcus, July 2018 (last commit before leaving)

            response.put("status", "PLACEHOLDER");
            response.put("message", "REST endpoint not yet connected to backend. " +
                "Use the JSF UI or mobile app for order creation.");
            response.put("note", "This was a CTO initiative. The CTO left. " +
                "Contact engineering manager for status.");

            return Response.ok(response).build();

        } catch (Exception e) {
            response.put("status", "ERROR");
            response.put("error", e.getMessage());
            return Response.serverError().entity(response).build();
        }
    }

    /**
     * Get order status.
     *
     * Works for POS orders AND web orders. This was the first
     * unified order lookup in the entire system. Before this,
     * you had to know whether an order was POS, web, or mobile
     * before you could look it up.
     *
     * Unfortunately, this endpoint was never advertised to other teams.
     * Most people still use the old source-specific lookups.
     */
    @GET
    @Path("/{orderId}/status")
    @Produces(MediaType.APPLICATION_JSON)
    public Response getOrderStatus(@PathParam("orderId") String orderId,
                                    @QueryParam("source") String source) {
        Map<String, Object> response = new HashMap<>();

        // Another placeholder. The API_ORDER_SERVICE.api_get_order_status
        // procedure exists but the Java wiring was never completed.
        response.put("orderId", orderId);
        response.put("status", "UNKNOWN");
        response.put("note", "Endpoint not fully implemented. See OrderRestController.java comments.");

        return Response.ok(response).build();
    }
}
