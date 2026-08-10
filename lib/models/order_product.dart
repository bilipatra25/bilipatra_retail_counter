class OrderProduct {
  final int qty;
  final String unit;
  final double price;
  final double discount; // 🔹 changed from int → double
  final double netAmount;
  final int productId;
  final int orderCartItemId;
  final String name;
  final String weight;
  final double gst;
  final double finalAmt;

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
    required this.gst,
    required this.finalAmt,
  });

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    return OrderProduct(
      qty: int.tryParse(json['qty']?.toString() ?? '0') ?? 0,
      unit: json['unit'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0.0, // 🔹 safe conversion
      netAmount: double.tryParse(json['net_amount']?.toString() ?? '0') ?? 0.0,
      productId: int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      orderCartItemId: int.tryParse(json['order_cart_item_id']?.toString() ?? '0') ?? 0,
      name: json['product_name'] ?? '',
      weight: json['product_weight'] ?? '',
      gst: double.tryParse(json['gst']?.toString() ?? '0') ?? 0.0,
      finalAmt: double.tryParse(json['final_amt']?.toString() ?? '0') ?? 0.0,
    );
  }
}
