-- ============================================================
-- BurgerQuick Seed Data - 2000
-- Just the first store and a few employees to get started
-- ============================================================

-- Initial employees (Store #1 - Flagship location)
INSERT INTO EMPLOYEES (employee_id, first_name, last_name, ssn, store_number, position, hourly_rate)
VALUES ('BQ-EMP-0001', 'Mike', 'Henderson', '123-45-6789', '1', 'Store Manager', 18.50);

INSERT INTO EMPLOYEES (employee_id, first_name, last_name, ssn, store_number, position, hourly_rate, manager_id)
VALUES ('BQ-EMP-0002', 'Tom', 'Reynolds', '234-56-7890', '1', 'Shift Lead', 12.00, 'BQ-EMP-0001');

INSERT INTO EMPLOYEES (employee_id, first_name, last_name, ssn, store_number, position, hourly_rate, manager_id)
VALUES ('BQ-EMP-0003', 'Lisa', 'Chen', '345-67-8901', '1', 'Cashier', 8.50, 'BQ-EMP-0002');

INSERT INTO EMPLOYEES (employee_id, first_name, last_name, ssn, store_number, position, hourly_rate, manager_id)
VALUES ('BQ-EMP-0004', 'James', 'Washington', '456-78-9012', '1', 'Cook', 9.00, 'BQ-EMP-0002');

INSERT INTO EMPLOYEES (employee_id, first_name, last_name, ssn, store_number, position, hourly_rate, manager_id)
VALUES ('BQ-EMP-0005', 'Maria', 'Garcia', '567-89-0123', '1', 'Cashier', 8.50, 'BQ-EMP-0002');

-- Initial inventory items
INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('BEEF-PATTY-4', 'Beef Patty (1/4 lb)', 'Protein', 'EACH', 200, 350, 0.45, 'Midwest Meats Co.');

INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('BUN-SESAME', 'Sesame Seed Bun', 'Bakery', 'EACH', 300, 500, 0.12, 'City Bakery Supply');

INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('LETTUCE-ICE', 'Iceberg Lettuce (shredded)', 'Produce', 'LB', 25, 40, 1.20, 'Fresh Farms Inc.');

INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('TOMATO-SLICE', 'Tomato (sliced)', 'Produce', 'LB', 30, 28, 1.50, 'Fresh Farms Inc.');

INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('FRIES-CRINKLE', 'Crinkle Cut Fries', 'Frozen', 'LB', 100, 80, 0.35, 'Golden Fry Distributors');

INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('SODA-COLA-SYRUP', 'Cola Syrup (5 gal)', 'Beverage', 'EACH', 5, 7, 45.00, 'BevCo');

INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('CHEESE-AMER', 'American Cheese Slice', 'Dairy', 'EACH', 300, 450, 0.08, 'DairyFresh');

INSERT INTO INVENTORY_ITEMS (item_sku, item_name, category, unit_type, par_level, current_qty, unit_cost, supplier_name)
VALUES ('PICKLE-CHIPS', 'Pickle Chips', 'Condiments', 'LB', 15, 22, 0.90, 'City Pickle Co.');

COMMIT;
