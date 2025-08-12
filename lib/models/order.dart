class Order {
  final int orderId;
  final int customerId;
  final String orderUsername;
  final String orderMobileNo;
  final String orderAddress;
  final String orderType;
  final String razorpayOrderId;
  final String orderStatus;
  final String gstAmount;
  final String totalDiscount;
  final String totalAmount;
  final int isActive;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;

  Order({
    required this.orderId,
    required this.customerId,
    required this.orderUsername,
    required this.orderMobileNo,
    required this.orderAddress,
    required this.orderType,
    required this.razorpayOrderId,
    required this.orderStatus,
    required this.gstAmount,
    required this.totalDiscount,
    required this.totalAmount,
    required this.isActive,
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderId: json['order_id'] ?? 0,
      customerId: json['customer_id'] ?? 0,
      orderUsername: json['order_username'] ?? '',
      orderMobileNo: json['order_mobile_no'] ?? '',
      orderAddress: json['order_address'] ?? '',
      orderType: json['order_type'] ?? '',
      razorpayOrderId: json['razorpay_order_id'] ?? '',
      orderStatus: json['order_status'] ?? '',
      gstAmount: json['GST_amount'] ?? '0',
      totalDiscount: json['total_discount'] ?? '0',
      totalAmount: json['total_amount'] ?? '0',
      isActive: json['is_active'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      lastUpdatedAt:
      DateTime.tryParse(json['last_updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}
