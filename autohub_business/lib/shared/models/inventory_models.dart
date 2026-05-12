/// Модели API склада (snake_case с бэкенда).
class InventoryItemModel {
  const InventoryItemModel({
    required this.id,
    required this.organizationId,
    required this.itemType,
    required this.name,
    required this.unit,
    this.category,
    this.description,
    this.brand,
    this.article,
    this.sku,
    this.barcode,
    this.purchasePriceKopecks,
    this.salePriceKopecks,
    required this.minStock,
    required this.trackStock,
    required this.allowFractional,
    required this.isActive,
    required this.quantityTotal,
    required this.quantityReserved,
    required this.quantityAvailable,
    this.externalId,
    this.externalSystem,
    this.syncStatus,
    this.lastSyncedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String organizationId;
  final String itemType;
  final String name;
  final String unit;
  final String? category;
  final String? description;
  final String? brand;
  final String? article;
  final String? sku;
  final String? barcode;
  final int? purchasePriceKopecks;
  final int? salePriceKopecks;
  final double minStock;
  final bool trackStock;
  final bool allowFractional;
  final bool isActive;
  final double quantityTotal;
  final double quantityReserved;
  final double quantityAvailable;
  final String? externalId;
  final String? externalSystem;
  final String? syncStatus;
  final String? lastSyncedAt;
  final String createdAt;
  final String updatedAt;

  bool get isBelowMinStock => quantityAvailable < minStock && trackStock;

  factory InventoryItemModel.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    int? i(dynamic v) => v == null ? null : (v is int ? v : int.tryParse('$v'));
    return InventoryItemModel(
      id: '${j['id']}',
      organizationId: '${j['organization_id']}',
      itemType: '${j['item_type'] ?? 'material'}',
      name: '${j['name'] ?? ''}',
      unit: '${j['unit'] ?? 'pcs'}',
      category: j['category'] as String?,
      description: j['description'] as String?,
      brand: j['brand'] as String?,
      article: j['article'] as String?,
      sku: j['sku'] as String?,
      barcode: j['barcode'] as String?,
      purchasePriceKopecks: i(j['purchase_price_kopecks']),
      salePriceKopecks: i(j['sale_price_kopecks']),
      minStock: d(j['min_stock']),
      trackStock: j['track_stock'] == true,
      allowFractional: j['allow_fractional'] == true,
      isActive: j['is_active'] != false,
      quantityTotal: d(j['quantity_total']),
      quantityReserved: d(j['quantity_reserved']),
      quantityAvailable: d(j['quantity_available']),
      externalId: j['external_id'] as String?,
      externalSystem: j['external_system'] as String?,
      syncStatus: j['sync_status'] as String?,
      lastSyncedAt: j['last_synced_at'] as String?,
      createdAt: '${j['created_at'] ?? ''}',
      updatedAt: '${j['updated_at'] ?? ''}',
    );
  }
}

class InventoryMovementModel {
  const InventoryMovementModel({
    required this.id,
    required this.organizationId,
    required this.inventoryItemId,
    this.itemName,
    this.stockBalanceId,
    required this.movementType,
    required this.sourceType,
    required this.quantity,
    required this.unit,
    required this.createdAt,
    this.comment,
    this.actorNameSnapshot,
  });

  final String id;
  final String organizationId;
  final String inventoryItemId;
  final String? itemName;
  final String? stockBalanceId;
  final String movementType;
  final String sourceType;
  final double quantity;
  final String unit;
  final String createdAt;
  final String? comment;
  final String? actorNameSnapshot;

  factory InventoryMovementModel.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    return InventoryMovementModel(
      id: '${j['id']}',
      organizationId: '${j['organization_id']}',
      inventoryItemId: '${j['inventory_item_id']}',
      itemName: j['item_name'] as String?,
      stockBalanceId: j['stock_balance_id'] as String?,
      movementType: '${j['movement_type'] ?? ''}',
      sourceType: '${j['source_type'] ?? ''}',
      quantity: d(j['quantity']),
      unit: '${j['unit'] ?? 'pcs'}',
      createdAt: '${j['created_at'] ?? ''}',
      comment: j['comment'] as String?,
      actorNameSnapshot: j['actor_name_snapshot'] as String?,
    );
  }
}
