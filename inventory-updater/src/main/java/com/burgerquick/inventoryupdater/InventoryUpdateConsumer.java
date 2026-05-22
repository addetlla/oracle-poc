package com.burgerquick.inventoryupdater;

import com.rabbitmq.client.Channel;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.amqp.support.AmqpHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Component
public class InventoryUpdateConsumer {

    private static final Logger log = LoggerFactory.getLogger(InventoryUpdateConsumer.class);

    private final InventoryItemRepository inventoryItemRepository;

    public InventoryUpdateConsumer(InventoryItemRepository inventoryItemRepository) {
        this.inventoryItemRepository = inventoryItemRepository;
    }

    @RabbitListener(queues = RabbitMQConfig.INVENTORY_UPDATE_QUEUE)
    public void handleUpdate(InventoryUpdateMessage msg, Channel channel,
                             @Header(AmqpHeaders.DELIVERY_TAG) long tag) throws IOException {
        int rows = inventoryItemRepository.applyQuantityChange(msg.getItemSku(), msg.getQuantityChange());
        if (rows == 0) {
            log.warn("SKU not found: {}", msg.getItemSku());
            channel.basicNack(tag, false, false);
        } else {
            channel.basicAck(tag, false);
        }
    }
}
