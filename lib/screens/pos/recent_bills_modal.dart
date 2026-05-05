import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 🟢 Required for state injection

import '../../services/api_service.dart';
import '../../providers/app_provider.dart';
import '../../models/cart_item_model.dart';
import '../../models/user.dart';
import '../../models/product.dart';

class RecentBillsModal extends StatefulWidget {
  const RecentBillsModal({super.key});

  @override
  State<RecentBillsModal> createState() => _RecentBillsModalState();
}

class _RecentBillsModalState extends State<RecentBillsModal> {
  bool _isLoading = true;
  List<dynamic> _orders = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRecentOrders();
  }

  Future<void> _fetchRecentOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService(context).orderList(1, 20);

      if (response['flag'] == 1 && response['code'] == 200) {
        setState(() {
          _orders = response['data']['result'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? "Failed to load orders");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String rawDate) {
    try {
      final DateTime dt = DateTime.parse(rawDate).toLocal();
      final months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return "${dt.day} ${months[dt.month - 1]} • $hour:$minute $ampm";
    } catch (e) {
      return rawDate;
    }
  }

  // 🟢 NEW: The powerful Edit Order function
  // 🟢 UPDATED: The powerful Edit Order function (Now with Discounts!)
  Future<void> _editOrder(int orderId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: CircularProgressIndicator(color: Colors.green),
          ),
    );

    try {
      final response = await ApiService(
        context,
      ).orderListById(orderId.toString());

      if (response['flag'] == 1 && response['data'] != null) {
        final data = response['data'];

        // 1. Reconstruct Customer
        final customerData = data['customer'] ?? {};
        final customer = UserModel(
          id: int.tryParse(customerData['id']?.toString() ?? '0') ?? 0,
          name: customerData['name'] ?? 'Walk-in Customer',
          number: customerData['contact'] ?? '',
          address: customerData['address'] ?? '',
        );

        // 2. 🟢 Extract Global Discount from the Invoice object
        final invoiceData = data['invoice'] ?? {};
        final double previousGlobalDiscount =
            double.tryParse(
              invoiceData['discount_percent']?.toString() ?? '0',
            ) ??
            0.0;

        // 3. Reconstruct the CartItems WITH their individual discounts
        final productList = data['product_list'] as List<dynamic>? ?? [];
        List<CartItem> cartItems = [];

        for (var p in productList) {
          final product = ProductModel(
            id: p['product_id'] ?? 0,
            name: p['product_name'] ?? 'Unknown Product',
            image: p['product_image'] ?? '',
            price: double.tryParse(p['price']?.toString() ?? '0') ?? 0.0,
            discountPrice:
                double.tryParse(p['discount_price']?.toString() ?? '0') ?? 0.0,
            description: p['product_description'] ?? '',
            weight: p['product_weight']?.toString() ?? '',
            manufactureBy: p['manufacture_by'] ?? '',
            mfd:
                DateTime.tryParse(p['product_mfd']?.toString() ?? '') ??
                DateTime.now(),
            expiry:
                DateTime.tryParse(p['product_expiry_date']?.toString() ?? '') ??
                DateTime.now().add(const Duration(days: 365)),
          );

          // 🟢 CRITICAL FIX: Read the true percentage field, not the absolute amount
          final double itemDiscountPercent =
              double.tryParse(p['item_discount_percent']?.toString() ?? '0') ??
              0.0;

          CartItem newItem = CartItem(
            product: product,
            quantity: p['qty'] ?? 1,
          );

          // 🟢 Only apply an override if the item actually had its own specific percentage saved
          if (itemDiscountPercent > 0) {
            newItem.hasCustomDiscount = true;
            newItem.discountType = DiscountType.percent;
            newItem.discountValue = itemDiscountPercent;
            newItem.discountBase = DiscountBase.sellingPrice;
          }

          cartItems.add(newItem);
        }

        // ... (inside _editOrder, right after the productList loop finishes) ...

        // 🟢 NEW: Extract the previously paid amount from the summary
        final summaryData = data['summary'] ?? {};
        final double previouslyPaid = double.tryParse(summaryData['paid_amount']?.toString() ?? '0') ?? 0.0;

        // 4. Inject into Provider!
        if (mounted) {
          Provider.of<AppProvider>(context, listen: false).loadExistingOrder(
            orderId,
            customer,
            cartItems,
            globalDiscountType: previousGlobalDiscount > 0 ? DiscountType.percent : DiscountType.none,
            globalDiscountValue: previousGlobalDiscount,
            previouslyPaid: previouslyPaid, // 🟢 Inject into the provider!
          );

          Navigator.pop(context); // Close loading dialog
          Navigator.pop(context); // Close Recent Bills Modal

          // ... rest of your code ...

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Order #$orderId recalled into cart!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Failed to load order details.");
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error loading order: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelOrder(int orderId) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text("Cancel Order?"),
            content: Text(
              "Are you sure you want to cancel Order #$orderId? This action cannot be undone.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  "No, Keep it",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  try {
                    final response = await ApiService(
                      context,
                    ).cancelOrder(orderId);
                    if (response['flag'] == 1 || response['code'] == 200) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("✅ Order cancelled successfully!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _fetchRecentOrders();
                      }
                    } else {
                      throw Exception(
                        response['message'] ?? "Failed to delete order",
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("❌ Error: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text("Yes, Cancel Order"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 850,
        height: 650,
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // HEADER
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 26,
                        color: Colors.blueGrey,
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Recent Orders",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text("Refresh"),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                        ),
                        onPressed: _fetchRecentOrders,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ==========================================
            // LIST AREA
            // ==========================================
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: Colors.green),
                      )
                      : _errorMessage != null
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      )
                      : _orders.isEmpty
                      ? const Center(
                        child: Text(
                          "No recent orders found.",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                      // ==========================================
                      // 🟢 UPDATED: LIST VIEW BUILDER
                      // ==========================================
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];

                          // 1. Extract ALL variables first!
                          final orderId =
                              order['order_id']?.toString() ?? 'N/A';
                          final orderType =
                              order['order_type']?.toString().toUpperCase() ??
                              'UNKNOWN';
                          final orderStatus =
                              order['order_status']?.toString().toLowerCase() ??
                              'unknown';
                          final formattedDate = _formatDate(
                            order['created_at'] ?? '',
                          );
                          final customerName =
                              order['order_username']?.toString() ??
                              'Walk-in Customer';
                          final mobileNo =
                              order['order_mobile_no']?.toString() ?? '';

                          // 2. Extract Financials
                          final totalAmount =
                              double.tryParse(
                                order['total_amount']?.toString() ?? '0',
                              ) ??
                              0;
                          final paidAmount =
                              double.tryParse(
                                order['paid_amount']?.toString() ?? '0',
                              ) ??
                              0;
                          final totalDiscount =
                              double.tryParse(
                                order['total_discount']?.toString() ?? '0',
                              ) ??
                              0;

                          // 3. 🟢 Ledger Math
                          final balanceDue = totalAmount - paidAmount;
                          final isPartiallyPaid =
                              orderStatus == 'pending' &&
                              paidAmount > 0 &&
                              balanceDue > 0;
                          final isOnline = orderType == 'ONLINE';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  // Icon
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color:
                                          isOnline
                                              ? Colors.blue.shade50
                                              : Colors.green.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isOnline
                                          ? Icons.qr_code_2
                                          : Icons.payments,
                                      color:
                                          isOnline
                                              ? Colors.blue.shade600
                                              : Colors.green.shade600,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Order Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              "Order #$orderId",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                              child: Text(
                                                orderType,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // 🟢 SMART STATUS BADGE
                                            if (isPartiallyPaid)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color:
                                                        Colors.purple.shade200,
                                                  ),
                                                ),
                                                child: Text(
                                                  "PARTIALLY PAID",
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Colors.purple.shade700,
                                                  ),
                                                ),
                                              )
                                            else if (orderStatus.isNotEmpty)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      orderStatus == 'success'
                                                          ? Colors
                                                              .green
                                                              .shade100
                                                          : (orderStatus ==
                                                                  'pending'
                                                              ? Colors
                                                                  .orange
                                                                  .shade100
                                                              : Colors
                                                                  .red
                                                                  .shade100),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  orderStatus.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        orderStatus == 'success'
                                                            ? Colors
                                                                .green
                                                                .shade800
                                                            : (orderStatus ==
                                                                    'pending'
                                                                ? Colors
                                                                    .orange
                                                                    .shade800
                                                                : Colors
                                                                    .red
                                                                    .shade800),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "$formattedDate  •  $customerName ${mobileNo.isNotEmpty && mobileNo != '0' ? '($mobileNo)' : ''}",
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 🟢 FINANCIALS COLUMN (Now shows Due Balance!)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "₹${totalAmount.toStringAsFixed(0)}",
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (isPartiallyPaid) ...[
                                        Text(
                                          "Paid: ₹${paidAmount.toStringAsFixed(0)}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          "Due: ₹${balanceDue.toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ] else if (totalDiscount > 0)
                                        Text(
                                          "Saved ₹${totalDiscount.toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.red,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(width: 20),
                                  Container(
                                    height: 30,
                                    width: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(width: 12),

                                  // Quick Action Icons
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_note),
                                        color: Colors.orange.shade700,
                                        tooltip: "Edit / Recall Order",
                                        splashRadius: 24,
                                        onPressed:
                                            () => _editOrder(
                                              int.tryParse(orderId) ?? 0,
                                            ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.print_outlined),
                                        color: Colors.blueGrey,
                                        tooltip: "Print Receipt",
                                        splashRadius: 24,
                                        onPressed: () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Printing receipt...",
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.red.shade400,
                                        tooltip: "Cancel Order",
                                        splashRadius: 24,
                                        onPressed:
                                            () => _cancelOrder(
                                              int.tryParse(orderId) ?? 0,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
