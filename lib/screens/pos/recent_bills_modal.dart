import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../providers/app_provider.dart';
import '../../models/cart_item_model.dart';
import '../../models/user.dart';
import '../../models/product.dart';
import '../../models/order_model.dart';
import '../../utils/PrinterHelper.dart';
import 'qr_payment_dialog.dart';

class RecentBillsModal extends StatefulWidget {
  const RecentBillsModal({super.key});

  @override
  State<RecentBillsModal> createState() => _RecentBillsModalState();
}

class _RecentBillsModalState extends State<RecentBillsModal> {
  bool _isLoading = true;
  List<dynamic> _orders = [];
  String? _errorMessage;

  // 🟢 NEW: Filter States
  String _selectedOrderType = 'ALL';
  bool _showOnlyDues = false;

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
      // 🟢 NEW: Pass filters to API (Limit increased to 50 for better filtering experience)
      final response = await ApiService(
        context,
      ).orderList(1, 50, orderType: _selectedOrderType, hasDues: _showOnlyDues);

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

  void _showPaymentDialog(Map<String, dynamic> order, double balanceDue) {
    final int orderId = int.tryParse(order['order_id']?.toString() ?? '0') ?? 0;
    final int customerId =
        int.tryParse(order['customer_id']?.toString() ?? '0') ?? 0;
    final String mobile = order['order_mobile_no']?.toString() ?? '';

    double payAmount = balanceDue;
    String method = 'cash';
    final TextEditingController amountCtrl = TextEditingController(
      text: balanceDue.toStringAsFixed(0),
    );
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text("Settle Pending Bill"),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order #$orderId  •  Total Bill: ₹${order['total_amount']}",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Balance Due:",
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "₹${balanceDue.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Paying Amount (₹)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          payAmount = double.tryParse(val) ?? 0.0;
                          if (payAmount > balanceDue) {
                            payAmount = balanceDue;
                            amountCtrl.text = balanceDue.toStringAsFixed(2);
                          }
                        });
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Payment Method",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text("Cash"),
                            value: "cash",
                            groupValue: method,
                            onChanged:
                                (val) => setModalState(() => method = val!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text("UPI"),
                            value: "online",
                            groupValue: method,
                            onChanged:
                                (val) => setModalState(() => method = val!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed:
                      isProcessing
                          ? null
                          : () async {
                            if (payAmount <= 0) return;
                            setModalState(() => isProcessing = true);
                            try {
                              final response = await ApiService(
                                context,
                              ).payPendingBill(
                                orderId: orderId,
                                customerId: customerId,
                                amount: payAmount,
                                paymentMethod: method,
                              );

                              Navigator.pop(ctx);

                              if (method == 'online') {
                                final qrImageUrl =
                                    response['data']['image_url'];
                                final result = await showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder:
                                      (context) => QRPaymentDialog(
                                        orderId: orderId,
                                        amount: payAmount,
                                        qrImageUrl: qrImageUrl,
                                        willPrint: false,
                                        customerMobile: mobile,
                                      ),
                                );
                                if (result == 'paid_no_print' ||
                                    result == 'paid_print' ||
                                    result == 'paid_force' ||
                                    result == 'paid' ||
                                    result == true) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "✅ UPI Repayment Successful!",
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "✅ Cash Repayment Successful!",
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }

                              _fetchRecentOrders();
                            } catch (e) {
                              setModalState(() => isProcessing = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("❌ Failed: $e"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                  child:
                      isProcessing
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text("Receive Payment"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _printOrder(int orderId) async {
    try {
      final res = await ApiService(context).orderListById(orderId.toString());
      if (res['flag'] == 1 && res['data'] != null) {
        OrderModelResponse order = OrderModelResponse.fromJson(res['data']);
        order.orderId = orderId.toString();
        await PrinterHelper.printInvoice(order);
      } else {
        throw Exception("Failed to load order details for printing");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "⚠️ Print failed: No Default Printer Configured.",
            ),
            backgroundColor: Colors.orange.shade900,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

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

        final customerData = data['customer'] ?? {};
        final customer = UserModel(
          id: int.tryParse(customerData['id']?.toString() ?? '0') ?? 0,
          name: customerData['name'] ?? 'Walk-in Customer',
          number: customerData['contact'] ?? '',
          address: customerData['address'] ?? '',
        );

        final invoiceData = data['invoice'] ?? {};
        final double previousGlobalDiscount =
            double.tryParse(
              invoiceData['discount_percent']?.toString() ?? '0',
            ) ??
            0.0;

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

          final double itemDiscountPercent =
              double.tryParse(p['item_discount_percent']?.toString() ?? '0') ??
              0.0;
          CartItem newItem = CartItem(
            product: product,
            quantity: p['qty'] ?? 1,
          );

          if (itemDiscountPercent > 0) {
            newItem.hasCustomDiscount = true;
            newItem.discountType = DiscountType.percent;
            newItem.discountValue = itemDiscountPercent;
            newItem.discountBase = DiscountBase.sellingPrice;
          }
          cartItems.add(newItem);
        }

        final summaryData = data['summary'] ?? {};
        final double previouslyPaid =
            double.tryParse(summaryData['paid_amount']?.toString() ?? '0') ??
            0.0;

        if (mounted) {
          Provider.of<AppProvider>(context, listen: false).loadExistingOrder(
            orderId,
            customer,
            cartItems,
            globalDiscountType:
                previousGlobalDiscount > 0
                    ? DiscountType.percent
                    : DiscountType.none,
            globalDiscountValue: previousGlobalDiscount,
            previouslyPaid: previouslyPaid,
          );

          Navigator.pop(context);
          Navigator.pop(context);

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

  // 🟢 Helper to build simple filter chips
  Widget _buildFilterChip(String label) {
    final isSelected = _selectedOrderType == label;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.blueGrey.shade700,
      backgroundColor: Colors.grey.shade200,
      onSelected: (bool selected) {
        if (selected) {
          setState(() => _selectedOrderType = label);
          _fetchRecentOrders();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
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

            // 🟢 NEW: FILTERS BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        "Filter: ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip('ALL'),
                      const SizedBox(width: 8),
                      _buildFilterChip('CASH'),
                      const SizedBox(width: 8),
                      _buildFilterChip('ONLINE'),
                      const SizedBox(width: 8),
                      _buildFilterChip('CREDIT'),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        "Pending Dues Only",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              _showOnlyDues
                                  ? Colors.orange.shade800
                                  : Colors.grey,
                        ),
                      ),
                      Switch(
                        value: _showOnlyDues,
                        activeColor: Colors.orange.shade700,
                        onChanged: (val) {
                          setState(() {
                            _showOnlyDues = val;
                            // If toggled ON, force selection to CREDIT or ALL so dues appear
                            if (val &&
                                _selectedOrderType != 'ALL' &&
                                _selectedOrderType != 'CREDIT') {
                              _selectedOrderType = 'CREDIT';
                            }
                          });
                          _fetchRecentOrders();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

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
                          "No recent orders found for matching filters.",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];

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

                          final balanceDue = totalAmount - paidAmount;
                          final isOnline = orderType == 'ONLINE';
                          final isCreditType = orderType == 'CREDIT';

                          final hasPendingDues =
                              isCreditType && (balanceDue > 0);

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
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color:
                                          isOnline
                                              ? Colors.blue.shade50
                                              : (isCreditType
                                                  ? Colors.orange.shade50
                                                  : Colors.green.shade50),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isOnline
                                          ? Icons.qr_code_2
                                          : (isCreditType
                                              ? Icons.menu_book
                                              : Icons.payments),
                                      color:
                                          isOnline
                                              ? Colors.blue.shade600
                                              : (isCreditType
                                                  ? Colors.orange.shade600
                                                  : Colors.green.shade600),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

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

                                            if (hasPendingDues)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color:
                                                        Colors.orange.shade200,
                                                  ),
                                                ),
                                                child: Text(
                                                  "CREDIT / DUE",
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Colors.orange.shade800,
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
                                      if (hasPendingDues) ...[
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

                                  Row(
                                    children: [
                                      if (hasPendingDues)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8.0,
                                          ),
                                          child: ElevatedButton.icon(
                                            onPressed:
                                                () => _showPaymentDialog(
                                                  order,
                                                  balanceDue,
                                                ),
                                            icon: const Icon(
                                              Icons.payment,
                                              size: 16,
                                            ),
                                            label: const Text("Pay Dues"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.green.shade700,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                          ),
                                        ),
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
                                        onPressed:
                                            () => _printOrder(
                                              int.tryParse(orderId) ?? 0,
                                            ),
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
