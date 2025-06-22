import 'order_product.dart';

class OrderModelResponse {
  final int orderId;
  final int customerId;
  final String customerName;
  final String mobileNo;
  final String address;
  final String orderType;
  final String orderStatus;
  final double gstAmount;
  final double totalDiscount;
  final double totalAmount;
  final List<OrderProduct> productList;

  OrderModelResponse({
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.mobileNo,
    required this.address,
    required this.orderType,
    required this.orderStatus,
    required this.gstAmount,
    required this.totalDiscount,
    required this.totalAmount,
    required this.productList,
  });

  factory OrderModelResponse.fromJson(Map<String, dynamic> json) {
    return OrderModelResponse(
      orderId: json['order_id'],
      customerId: json['customer_id'],
      customerName: json['customer_name'],
      mobileNo: json['mobile_no'],
      address: json['address'],
      orderType: json['order_type'],
      orderStatus: json['order_status'],
      gstAmount: double.tryParse(json['GST_amount'].toString()) ?? 0,
      totalDiscount: double.tryParse(json['total_discount'].toString()) ?? 0,
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0,
      productList:
          (json['product_list'] as List)
              .map((e) => OrderProduct.fromJson(e))
              .toList(),
    );
  }
}
