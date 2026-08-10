import 'order_product.dart';

class OrderModelResponse {
  String orderId;
  final String customerName;
  final String mobileNo;
  final String address;
  final String orderType;
  final String invoiceNumber;
  final String invoiceDate;
  final double subTotal;
  final double discount;
  final double sgst;
  final double cgst;
  final double total;
  final double received;
  final List<OrderProduct> productList;

  OrderModelResponse({
    required this.orderId,
    required this.customerName,
    required this.mobileNo,
    required this.address,
    required this.orderType,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.subTotal,
    required this.discount,
    required this.sgst,
    required this.cgst,
    required this.total,
    required this.received,
    required this.productList,
  });

  factory OrderModelResponse.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] ?? {};
    final invoice = json['invoice'] ?? {};
    final summary = json['summary'] ?? {};

    return OrderModelResponse(
      orderId: customer['order_id'] ?? '',
      customerName: customer['name'] ?? '',
      mobileNo: customer['contact'] ?? '',
      address: customer['address'] ?? '',
      orderType: invoice['order_type'] ?? '',
      invoiceNumber: invoice['number'] ?? '',
      invoiceDate: invoice['date'] ?? '',
      subTotal: double.tryParse(summary['sub_total'].toString()) ?? 0,
      discount: double.tryParse(summary['discount'].toString()) ?? 0,
      sgst: double.tryParse(summary['sgst'].toString()) ?? 0,
      cgst: double.tryParse(summary['cgst'].toString()) ?? 0,
      total: double.tryParse(summary['total'].toString()) ?? 0,
      received: double.tryParse(summary['received'].toString()) ?? 0,
      productList:
          (json['product_list'] as List? ?? [])
              .map((e) => OrderProduct.fromJson(e))
              .toList(),
    );
  }
}
