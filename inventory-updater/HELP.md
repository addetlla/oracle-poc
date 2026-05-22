# Inventory Updater

Spring Boot service that consumes inventory update messages from RabbitMQ and atomically applies quantity changes to the Oracle `INVENTORY_ITEMS` table.

## Prerequisites

- **Java 17** (OpenJDK 17.0.18+)
- **Oracle 19c** running on `localhost:1521/ORCLPDB1` (the `oracle19c` Docker container)
- **RabbitMQ** running on `localhost:5672` with management UI on `:15672` (the `bq-rabbitmq` Docker container)
- The `INVENTORY_ITEMS` table must exist (created by `install_all.sql`)

## Quick Start

Credentials are passed via environment variables — never stored in the properties file.

```bash
# Set credentials in your shell (or add to ~/.bashrc / ~/.profile)
export ORACLE_PASSWORD=Oracle123!
export RABBITMQ_PASSWORD=guest

# 1. Start the app
./mvnw spring-boot:run

# 2. In another terminal, publish test messages for N minutes
./publish-test-message.sh 1
```

## Build

```bash
./mvnw clean compile      # compile only
./mvnw clean package      # create executable JAR
```

## How It Works

```
publish-test-message.sh ──► RabbitMQ ──► InventoryUpdateConsumer
                                │              │
                   inventory-update-queue      │
                                               ▼
                                     InventoryItemRepository
                                     .applyQuantityChange()
                                               │
                                               ▼
                                     Oracle INVENTORY_ITEMS
                                     SET current_qty = current_qty + :delta
```

1. The bash script publishes JSON messages to `inventory-update-queue` via the RabbitMQ management API
2. `InventoryUpdateConsumer` receives messages through `@RabbitListener`
3. The consumer calls `applyQuantityChange()` which runs an atomic `UPDATE ... SET current_qty = current_qty + ?` — no read-then-write race condition
4. If the SKU is not found, the message is rejected without requeue (logged as a warning)
5. On success, the message is manually acknowledged

## Project Structure

```
src/main/java/com/burgerquick/inventoryupdater/
├── InventoryUpdaterApplication.java   # Spring Boot entry point
├── InventoryItem.java                 # JPA entity → INVENTORY_ITEMS table
├── InventoryItemRepository.java       # JPA repository with atomic update query
├── RabbitMQConfig.java                # Queue + Jackson2JsonMessageConverter beans
├── InventoryUpdateMessage.java        # DTO: {itemSku, quantityChange}
└── InventoryUpdateConsumer.java       # @RabbitListener with manual ack/nack
```

## Configuration

Non-sensitive properties in `application.properties`. Credentials come from environment variables.

| Property | Value | Notes |
|----------|-------|-------|
| `spring.datasource.url` | `jdbc:oracle:thin:@//localhost:1521/ORCLPDB1` | Oracle 19c container |
| `spring.datasource.username` | `system` | Default Oracle admin user |
| `spring.datasource.password` | `${ORACLE_PASSWORD}` | Set via env var |
| `spring.rabbitmq.host` | `localhost` | RabbitMQ container |
| `spring.rabbitmq.port` | `5672` | AMQP port |
| `spring.rabbitmq.username` | `guest` | Default RabbitMQ user |
| `spring.rabbitmq.password` | `${RABBITMQ_PASSWORD}` | Set via env var |
| `spring.rabbitmq.listener.simple.acknowledge-mode` | `manual` | Explicit ack/nack in consumer |
| `spring.jpa.hibernate.ddl-auto` | `none` | Schema managed by install_all.sql |

## Test Script

`publish-test-message.sh` publishes randomized updates every 5 seconds to three SKUs: `BEEF-PATTY-4`, `BUN-SESAME`, `FRIES-CRINKLE`. Each update adjusts quantity by +1 to +20.

Verify results:
```sql
SELECT item_sku, item_name, current_qty FROM INVENTORY_ITEMS;
```

## Key Design Decisions

- **Atomic update**: Uses `SET current_qty = current_qty + :delta` in the database rather than a read-then-write in application code. Prevents lost updates under concurrent consumers.
- **Manual ack**: Consumer explicitly acks on success, nacks (without requeue) on permanent failures like unknown SKUs. Default `auto` ack would retry poison messages indefinitely.
- **Default exchange**: Uses the AMQP default exchange for simplicity — the queue name doubles as the routing key. Suitable for a single-queue setup.
