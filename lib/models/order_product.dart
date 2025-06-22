class OrderProduct {
  final int qty;
  final String unit;
  final double price;
  final int discount;
  final String name;
  final String weight;

  OrderProduct({
    required this.qty,
    required this.unit,
    required this.price,
    required this.discount,
    required this.name,
    required this.weight,
  });

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    return OrderProduct(
      qty: json['qty'],
      unit: json['unit'],
      price: double.tryParse(json['price'].toString()) ?? 0,
      discount: json['discount'],
      name: json['product_name'],
      weight: json['product_weight'],
    );
  }
}
