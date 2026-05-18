package model.rest;

/**
 * Delivery REST Controller
 * Author: Dave (Emergency Contractor), April 2020
 *
 * Built in 3 days during the pandemic rush to add delivery.
 * Copied the structure from OrderRestController (Marcus, 2018)
 * which copied its structure from a Spring Boot tutorial Marcus found online.
 *
 * This controller was supposed to be temporary.
 * It's now handling 30% of all orders.
 *
 * - Dave (contract ended May 2020)
 */
public class DeliveryController {

    // TODO: Implement delivery REST endpoints
    // The delivery module was built so fast we didn't have time
    // to set up REST properly. The mobile app calls DELIVERY_PKG
    // directly through a database connection. Yes, the mobile app
    // has a direct DB connection. The CISO doesn't know.
    //
    // When we eventually fix this:
    // 1. Create proper REST endpoints for create/update/cancel delivery
    // 2. Remove direct DB access from mobile app
    // 3. Add authentication (currently delivery endpoints have none)
    // 4. Add rate limiting (we had a scraper incident in 2021)
    //
    // Estimated effort: 3 weeks with proper testing
    // Priority: "When we have time" (we never have time)
}
