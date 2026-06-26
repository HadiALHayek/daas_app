class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.cost,
    required this.sellPrice,
    required this.currency,
    this.createdAt,
  });

  final String id;
  final String name;
  final double cost;
  final double sellPrice;
  final String currency;
  final DateTime? createdAt;

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      id: json['id'] as String,
      name: json['name'] as String,
      cost: (json['cost'] as num).toDouble(),
      sellPrice: (json['sell_price'] as num).toDouble(),
      currency: json['currency'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'cost': cost,
        'sell_price': sellPrice,
        'currency': currency,
      };
}
