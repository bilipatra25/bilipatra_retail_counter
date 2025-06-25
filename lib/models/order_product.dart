class OrderProduct {
  final int qty;
  final String unit;
  final double price;
  final int discount;
  final double netAmount;
  final int productId;
  final int orderCartItemId;
  final String name;
  final String weight;

  OrderProduct({
    required this.qty,
    required this.unit,
    required this.price,
    required this.discount,
    required this.netAmount,
    required this.productId,
    required this.orderCartItemId,
    required this.name,
    required this.weight,
  });

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    return OrderProduct(
      qty: json['qty'] ?? 0,
      unit: json['unit'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      discount: json['discount'] ?? 0,
      netAmount: double.tryParse(json['net_amount']?.toString() ?? '') ?? 0.0,
      productId: json['product_id'] ?? 0,
      orderCartItemId: json['order_cart_item_id'] ?? 0,
      name: json['product_name'] ?? '',
      weight: json['product_weight'] ?? '',
    );
  }
}
