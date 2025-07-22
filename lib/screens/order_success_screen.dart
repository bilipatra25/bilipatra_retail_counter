import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../PrintScreen.dart';
import '../models/order_model.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';

class OrderSuccessScreen extends StatefulWidget {
  final int orderId;

  const OrderSuccessScreen({super.key, required this.orderId});

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  bool _isLoading = true;
  OrderModelResponse? order;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    try {
      final api = ApiService(context);
      final res = await api.orderListById(widget.orderId.toString());

      if (res['flag'] == 1 && res['data'] != null && res['data'].isNotEmpty) {
        setState(() {
          order = OrderModelResponse.fromJson(res['data'][0]);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load order details.")),
        );
      }
    } catch (e) {
      print("❌ Error loading order: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error loading order: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePrintInvoice(user, products) async {
    /*setState(() => _isLoading = true);
    try {
      await InvoiceGeneratorEzo.generateInvoicePdf(user, products);
    } catch (e) {
      debugPrint("Error generating PDF: $e");
    } finally {
      setState(() => _isLoading = false);
    }*/
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => PrintScreen(user: user, products: products),
    //   ),
    // );
  }

  Future<void> _generatePdfInBackground(user, products) async {
    await compute(generatePdfTask, {'user': user, 'products': products});
  }

  // Place this at the top level of your file or in another utils file
  Future<void> generatePdfTask(Map<String, dynamic> args) async {
    final user = args['user'];
    final products = args['products'];
    // await InvoiceGenerator.generateInvoicePdf(user, products);
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              "Invoice",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
                  Text("Payment Mode: ${order!.orderType.toUpperCase()}"),
                ],
              ),
            ),
          ),
          const Text(
            "Items",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(4),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
            },
            border: TableBorder.all(color: Colors.grey.shade300),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade200),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Product",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Qty",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Rate",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Amount",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
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
                      child: Text("₹${p.price.toStringAsFixed(2)}"),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("₹${p.netAmount.toStringAsFixed(2)}"),
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
                Text("Subtotal: ₹${(order!.subTotal).toStringAsFixed(2)}"),
                Text("GST: ₹${order!.gstAmount.toStringAsFixed(2)}"),
                Text("Discount: ₹${order!.totalDiscount.toStringAsFixed(2)}"),
                const Divider(thickness: 1),
                Text(
                  "Total: ₹${order!.totalAmount.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final appProvider = Provider.of<AppProvider>(
                      context,
                      listen: false,
                    );
                    final user = appProvider.user;
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Wrap(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                              child: PrintScreen(user: user, order: order!),
                            ),
                          ],
                        ),
                      ),
                    );


  /*                  showDialog(
                      context: context,
                      builder: (_) => Dialog.fullscreen(
                        child: PrintScreen(user: user, order: order!),
                      ),
                    );*/

/*
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrintScreen(user: user, order: order!),
                        fullscreenDialog: true,
                      ),
                    );*/

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
                    final confirm = await showConfirmHomeDialog(context);
                    if (confirm) {
                      context.go('/');
                    }
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
          const SizedBox(height: 16),
        ],
      ),
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

  /*
  Widget _buildOrderSummary() {
    final userName = orderData?['customer_name'] ?? '-';
    final phone = orderData?['mobile_no'] ?? '-';
    final address = orderData?['address'] ?? '-';
    final total = orderData?['total_amount'] ?? '0';
    final products = orderData?['product_list'] ?? [];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            "Your order has been placed successfully!",
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text("Order ID: #${widget.orderId}"),
          const SizedBox(height: 20),

          Card(
            child: ListTile(
              title: Text("Customer: $userName"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text("Phone: $phone"), Text("Address: $address")],
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Text(
            "Products:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...products.map<Widget>((item) {
            return ListTile(
              title: Text(
                "${item['product_name']} (${item['product_weight']})",
              ),
              subtitle: Text("Qty: ${item['qty']} × ₹${item['price']}"),
              trailing: Text(
                "₹${(item['qty'] * item['price']).toStringAsFixed(2)}",
              ),
            );
          }).toList(),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "Total: ₹$total",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.arrow_back),
            label: const Text("Back to Home"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () {
              final appProvider = Provider.of<AppProvider>(context, listen: false);
              final user = appProvider.user;
              // final products = appProvider.selectedProducts;
              // TODO: Pass actual user and product list to PrintScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrintScreen(user: user, products: products),
                ),
              );
            },
            icon: const Icon(Icons.print),
            label: const Text("Print Invoice"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: () async {
              // TODO: Add WhatsApp sharing logic
            },
            icon: const Icon(Icons.share),
            label: const Text("Send via WhatsApp"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }*/
}
