import 'package:flutter/material.dart';
import '../../services/api_service.dart';

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

  // Formats date cleanly: "30 Apr • 12:30 PM"
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
        width: 850, // Slightly wider for the horizontal layout
        height: 650,
        padding: const EdgeInsets.all(
          0,
        ), // Removed outer padding for edge-to-edge header
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
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];

                          // Extraction
                          final orderId =
                              order['order_id']?.toString() ?? 'N/A';
                          final totalAmount =
                              order['total_amount']?.toString() ?? '0.00';
                          final orderType =
                              order['order_type']?.toString().toUpperCase() ??
                              'UNKNOWN';
                          final formattedDate = _formatDate(
                            order['created_at'] ?? '',
                          );
                          final customerName =
                              order['order_username']?.toString() ??
                              'Walk-in Customer';
                          final mobileNo =
                              order['order_mobile_no']?.toString() ?? '';
                          final totalDiscount =
                              double.tryParse(
                                order['total_discount']?.toString() ?? '0',
                              ) ??
                              0;

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
                                  // 1. Sleek Icon indicator
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

                                  // 2. Order Details (Main Block)
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
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        // Subtitle: Combines Date + Name + Mobile into one clean line
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

                                  // 3. Financials
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "₹$totalAmount",
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (totalDiscount > 0)
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

                                  // Subtle vertical divider separating data from actions
                                  Container(
                                    height: 30,
                                    width: 1,
                                    color: Colors.grey.shade300,
                                  ),

                                  const SizedBox(width: 12),

                                  // 4. Quick Action Icons
                                  Row(
                                    children: [
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
