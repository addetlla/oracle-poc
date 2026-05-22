package com.burgerquick.inventoryupdater;

import jakarta.transaction.Transactional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface InventoryItemRepository extends JpaRepository<InventoryItem, String> {

    @Modifying
    @Transactional
    @Query("UPDATE InventoryItem SET currentQty = currentQty + :delta WHERE itemSku = :sku")
    int applyQuantityChange(@Param("sku") String sku, @Param("delta") int delta);
}
