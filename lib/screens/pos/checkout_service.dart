import 'dart:convert';
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

    if (provider.isEditingOrder) {
      return await apiService.updateOrder(payload);
    } else {
      return await apiService.placeOrder(payload);
    }
  }

  // 🟢 NEW: Credit / Udhar Order Flow
  static Future<Map<String, dynamic>> placeCreditOrder(
    BuildContext context,
    AppProvider provider,
    double paidAmount,
    String advancePaymentMethod,
  ) async {
    final Map<String, dynamic> payload = _buildPayload(
      provider,
      "credit",
      paidAmount,
      advancePaymentMethod,
    );

    debugPrint("📦 Sending Credit Payload to API: ${jsonEncode(payload)}");
    final apiService = ApiService(context);

    if (provider.isEditingOrder) {
      return await apiService.updateOrder(payload);
    } else {
      return await apiService.placeOrder(payload);
    }
  }

  // 🟢 HELPER: Keeps your code DRY
  static Map<String, dynamic> _buildPayload(
    AppProvider provider,
    String orderType, [
    double paidAmount = 0.0,
    String advancePaymentMethod = 'none',
  ]) {
    double finalGlobalDiscountPercent = 0.0;

    if (provider.globalDiscountValue > 0) {
      if (provider.globalDiscountType == DiscountType.percent) {
        if (provider.globalDiscountBase == DiscountBase.mrp) {
          double totalMrp = provider.cart.fold(
            0.0,
            (sum, item) =>
                sum +
                (item.hasCustomDiscount || item.isFreeItem
                    ? 0.0
                    : item.totalMrp),
          );
          double discountAmount =
              (totalMrp * provider.globalDiscountValue) / 100;
          double subtotal = provider.cartSubtotal;
          if (subtotal > 0) {
            finalGlobalDiscountPercent = (discountAmount / subtotal) * 100;
          }
        } else {
          finalGlobalDiscountPercent = provider.globalDiscountValue;
        }
      } else if (provider.globalDiscountType == DiscountType.flat) {
        double subtotal = provider.cartSubtotal;
        if (subtotal > 0) {
          finalGlobalDiscountPercent =
              (provider.globalDiscountValue / subtotal) * 100;
        }
      }
    }

    final payload = <String, dynamic>{
      "order_type": orderType,
      "customer_id": provider.activeCustomerId,
      "discount_percent": double.parse(
        finalGlobalDiscountPercent.toStringAsFixed(4),
      ),
      // 🟢 NEW: Pass Advance Payment Data
      "paid_amount": paidAmount,
      "advance_payment_method": advancePaymentMethod,
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

    if (provider.isEditingOrder) {
      payload["order_id"] = provider.editingOrderId;
    }

    return payload;
  }

  static Future<bool> sendWhatsAppQR(
    BuildContext context,
    int orderId,
    String mobile,
    String qrImageUrl,
  ) async {
    try {
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
