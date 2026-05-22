package com.burgerquick.inventoryupdater;

public class InventoryUpdateMessage {

    private String itemSku;
    private int quantityChange;

    public InventoryUpdateMessage() {}

    public InventoryUpdateMessage(String itemSku, int quantityChange) {
        this.itemSku = itemSku;
        this.quantityChange = quantityChange;
    }

    public String getItemSku() {
        return itemSku;
    }

    public void setItemSku(String itemSku) {
        this.itemSku = itemSku;
    }

    public int getQuantityChange() {
        return quantityChange;
    }

    public void setQuantityChange(int quantityChange) {
        this.quantityChange = quantityChange;
    }
}
