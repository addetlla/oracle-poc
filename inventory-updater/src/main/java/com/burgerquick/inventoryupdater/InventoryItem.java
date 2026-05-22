package com.burgerquick.inventoryupdater;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "INVENTORY_ITEMS")
public class InventoryItem {

    @Id
    @Column(name = "item_sku")
    private String itemSku;

    @Column(name = "current_qty")
    private int currentQty;

    public InventoryItem() {}

    public InventoryItem(String itemSku, int currentQty) {
        this.itemSku = itemSku;
        this.currentQty = currentQty;
    }

    public String getItemSku() {
        return itemSku;
    }

    public void setItemSku(String itemSku) {
        this.itemSku = itemSku;
    }

    public int getCurrentQty() {
        return currentQty;
    }

    public void setCurrentQty(int currentQty) {
        this.currentQty = currentQty;
    }
}
