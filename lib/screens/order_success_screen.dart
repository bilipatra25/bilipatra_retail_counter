import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../PrintScreen.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../utils/PrinterHelper.dart';
import '../utils/globals.dart';
import 'invoice_webview_screen.dart';

class OrderSuccessScreen extends StatefulWidget {
  final int orderId;

  const OrderSuccessScreen({super.key, required this.orderId});

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  bool _isLoading = true;
  OrderModelResponse? order;
  bool _autoPrintEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadAutoPrintSetting();
    _loadOrderDetails();
  }

  Future<void> _loadAutoPrintSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoPrintEnabled = prefs.getBool("auto_print_enabled") ?? true;
    });
  }

  Future<void> _loadOrderDetails() async {
    try {
      final api = ApiService(context);
      final res = await api.orderListById(widget.orderId.toString());

      if (res['flag'] == 1 && res['data'] != null) {
        setState(() {
          order = OrderModelResponse.fromJson(res['data']);
        });
        if (_autoPrintEnabled && order != null) {
          await _handleAutoPrint(order!);
        }
      } else {
        showAppSnackBar(context, "Failed to load order details.");
      }
    } catch (e) {
      print("❌ Error loading order: $e");
      showAppSnackBar(context, "❌ Error loading order: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAutoPrint(OrderModelResponse loadedOrder) async {
    // ✅ Proceed with print
    final success = await PrinterHelper.printInvoice(loadedOrder);
    if (success) {
      debugPrint("🟢 Order ${loadedOrder.invoiceNumber} printed successfully");
    } else {
      debugPrint("🔴 Failed to print order ${loadedOrder.invoiceNumber}");
    }

    if (mounted) {
      showAppSnackBar(
        context,
        success ? "✅ Invoice printed" : "⚠️ Print failed. Check printer.",
        success: success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final confirm = await showConfirmHomeDialog(context);
        if (confirm) {
          context.go('/');
        }
        return false; // prevent default pop
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text("Order Placed"),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : order == null
                ? const Center(child: Text("No order data found"))
                : _buildOrderSummary(context),
      ),
    );
  }

  Widget _buildOrderSummary(BuildContext context) {
    if (order == null) return const Text("Order not found");

    return Column(
      children: [
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  color: Colors.grey.shade200,
                  child: const TabBar(
                    labelColor: Colors.black,
                    indicatorColor: Colors.green,
                    tabs: [Tab(text: "Summary"), Tab(text: "Invoice")],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // 🔹 Order Summary Tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                "Invoice",
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: ListTile(
                                title: Text("Customer: ${order!.customerName}"),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Mobile: ${order!.mobileNo}"),
                                    Text("Address: ${order!.address}"),
                                    Text(
                                      "Payment Mode: ${order!.orderType.toUpperCase()}",
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Text(
                              "Items",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Table(
                              columnWidths: const {
                                0: FlexColumnWidth(3), // Product
                                1: FlexColumnWidth(2), // Qty
                                2: FlexColumnWidth(2), // Rate
                                3: FlexColumnWidth(2), // GST
                                4: FlexColumnWidth(2), // Final Amount
                              },
                              border: TableBorder.all(
                                color: Colors.grey.shade300,
                              ),
                              children: [
                                // 🔹 Header Row
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                  ),
                                  children: const [
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        "Product",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        "Qty",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        "Rate",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        "GST %",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        "Final Amt",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ), // 🔹 Product Rows
                                ...order!.productList.map((p) {
                                  return TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text("${p.name} (${p.weight})"),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text("${p.qty} ${p.unit}"),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "₹${p.price.toStringAsFixed(2)}",
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "${p.gst.toStringAsFixed(2)}",
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "₹${p.finalAmt.toStringAsFixed(2)}",
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "Subtotal: ₹${order!.subTotal.toStringAsFixed(2)}",
                                  ),
                                  Text(
                                    "SGST(2.5%): ₹${order!.sgst.toStringAsFixed(2)}",
                                  ),
                                  Text(
                                    "CGST(2.5%): ₹${order!.cgst.toStringAsFixed(2)}",
                                  ),
                                  Text(
                                    "Discount: ₹${order!.discount.toStringAsFixed(2)}",
                                  ),
                                  const Divider(thickness: 1),
                                  Text(
                                    "Total: ₹${order!.total.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    "Received: ₹${order!.received.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),

                      // 🔹 Invoice WebView Tab
                      InvoiceWebViewScreen(
                        url:
                            "${ApiService.baseUrl}/invoice/internal-invoice-preview?order_id=${widget.orderId.toString()}",
                        // or widget default URL
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 🔹 Bottom buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder:
                          (context) => Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Wrap(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 20,
                                  ),
                                  child: PrintScreen(order: order!),
                                ),
                              ],
                            ),
                          ),
                    );
                  },
                  icon: const Icon(Icons.print),
                  label: const Text("Print Invoice"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // final confirm = await showConfirmHomeDialog(context);
                    // if (confirm) {
                    context.go('/');
                    // }
                  },
                  icon: const Icon(Icons.home),
                  label: const Text("Back to Home"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> showConfirmHomeDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text("Confirm Navigation"),
                content: const Text(
                  "Are you sure you want to go back to Home?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Yes"),
                  ),
                ],
              ),
        ) ??
        false; // default to false if null
  }
}
