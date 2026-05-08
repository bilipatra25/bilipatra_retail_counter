import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/cart_item_model.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';

class CheckoutService {
  static Future<Map<String, dynamic>> placeCashOrder(
      BuildContext context,
      AppProvider provider,
      ) async {
    final Map<String, dynamic> payload = _buildPayload(provider, "cash");

    debugPrint("📦 Sending Cash Payload to API: ${jsonEncode(payload)}");
    final apiService = ApiService(context);

    // 🟢 THE FORK: Update vs Insert
    if (provider.isEditingOrder) {
      return await apiService.updateOrder(payload);
    } else {
      return await apiService.placeOrder(payload);
    }
  }

  static Future<Map<String, dynamic>> placeOnlineOrder(
      BuildContext context,
      AppProvider provider,
      ) async {
    final Map<String, dynamic> payload = _buildPayload(provider, "online");

    debugPrint("📦 Sending Online Payload to API: ${jsonEncode(payload)}");
    final apiService = ApiService(context);

    // 🟢 THE FORK: Update vs Insert
    if (provider.isEditingOrder) {
      return await apiService.updateOrder(payload);
    } else {
      return await apiService.placeOrder(payload);
    }
  }

  // 🟢 HELPER: Keeps your code DRY so we don't repeat the payload building logic
  static Map<String, dynamic> _buildPayload(
      AppProvider provider,
      String orderType,
      ) {
    // 🟢 FIX: Dynamically convert Flat Amount Global Discounts into Percentages
    double finalGlobalDiscountPercent = 0.0;

    if (provider.globalDiscountValue > 0) {
      if (provider.globalDiscountType == DiscountType.percent) {
        finalGlobalDiscountPercent = provider.globalDiscountValue;
      } else if (provider.globalDiscountType == DiscountType.flat) {
        // Calculate what percentage the flat amount represents against the subtotal
        double subtotal = provider.cartSubtotal;
        if (subtotal > 0) {
          finalGlobalDiscountPercent = (provider.globalDiscountValue / subtotal) * 100;
        }
      }
    }

    final payload = <String, dynamic>{
      "order_type": orderType,
      "customer_id": provider.activeCustomerId,
      // Send the calculated percentage to the backend
      "discount_percent": double.parse(finalGlobalDiscountPercent.toStringAsFixed(4)),
      "product_list":
      provider.cart.map((item) {
        double baseTotal =
        item.discountBase == DiscountBase.mrp
            ? item.totalMrp
            : item.totalSellingPrice;
        return {
          "product_id": item.product.id,
          "qty": item.quantity,
          "unit": "pcs",
          "discount":
          item.discountType == DiscountType.percent
              ? item.discountValue
              : (item.discountType == DiscountType.flat &&
              baseTotal > 0)
              ? (item.discountValue / baseTotal) * 100
              : 0.0,
        };
      }).toList(),
    };

    // 🟢 CRITICAL: Inject order_id if we are editing!
    if (provider.isEditingOrder) {
      payload["order_id"] = provider.editingOrderId;
    }

    return payload;
  }

  // Inside checkout_service.dart
  static Future<bool> sendWhatsAppQR(
      BuildContext context,
      int orderId,
      String mobile,
      String
      qrImageUrl, // We keep this parameter so the UI doesn't break, but we don't need to send it to the backend!
      ) async {
    try {
      // 🟢 Use the unified API method!
      final response = await ApiService(
        context,
      ).sendPaymentWhatsapp(orderId, mobile);

      return response['flag'] == 1 || response['code'] == 200;
    } catch (e) {
      debugPrint("Error sending WhatsApp QR: $e");
      rethrow;
    }
  }
}