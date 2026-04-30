import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // 🟢 Added for BuildContext

import '../../models/cart_item_model.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart'; // 🟢 Import your ApiService

class CheckoutService {

  static Future<Map<String, dynamic>> placeCashOrder(BuildContext context, AppProvider provider) async {
    final Map<String, dynamic> payload = {
      "order_type": "cash",
      "customer_id": provider.activeCustomerId,
      "discount_percent": provider.globalDiscountType == DiscountType.percent
          ? provider.globalDiscountValue
          : 0.0,
      "product_list": provider.cart.map((item) {
        double baseTotal = item.discountBase == DiscountBase.mrp
            ? item.totalMrp
            : item.totalSellingPrice;
        return {
          "product_id": item.product.id,
          "qty": item.quantity,
          "unit": "pcs",
          "discount": item.discountType == DiscountType.percent
              ? item.discountValue
              : (item.discountType == DiscountType.flat && baseTotal > 0)
              ? (item.discountValue / baseTotal) * 100
              : 0.0,
        };
      }).toList(),
    };

    debugPrint("📦 Sending Cash Payload to API: ${jsonEncode(payload)}");

    // 🟢 Call your live ApiService
    final apiService = ApiService(context);
    return await apiService.placeOrder(payload); // Returns the 'data' object directly
  }

  static Future<Map<String, dynamic>> placeOnlineOrder(BuildContext context, AppProvider provider) async {
    final Map<String, dynamic> payload = {
      "order_type": "online",
      "customer_id": provider.activeCustomerId,
      "discount_percent": provider.globalDiscountType == DiscountType.percent
          ? provider.globalDiscountValue
          : 0.0,
      "product_list": provider.cart.map((item) {
        double baseTotal = item.discountBase == DiscountBase.mrp ? item.totalMrp : item.totalSellingPrice;
        return {
          "product_id": item.product.id,
          "qty": item.quantity,
          "unit": "pcs",
          "discount": item.discountType == DiscountType.percent ? item.discountValue
              : (item.discountType == DiscountType.flat && baseTotal > 0) ? (item.discountValue / baseTotal) * 100 : 0.0,
        };
      }).toList(),
    };

    debugPrint("📦 Sending Online Payload to API: ${jsonEncode(payload)}");

    // 🟢 Call your live ApiService
    final apiService = ApiService(context);
    return await apiService.placeOrder(payload); // Returns the 'data' object directly
  }

  static Future<bool> sendWhatsAppQR(BuildContext context, int orderId, String mobileNo, String qrUrl) async {
    final payload = {
      "order_id": orderId,
      "mobile_no": mobileNo,
      "qr_url": qrUrl,
    };
    debugPrint("💬 Triggering WhatsApp API: ${jsonEncode(payload)}");

    // 🟢 Call your live ApiService
    final apiService = ApiService(context);
    return await apiService.sendQrWhatsApp(payload);
  }
}