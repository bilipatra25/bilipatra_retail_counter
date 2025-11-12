import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/globals.dart';
// import 'dart:html' as html;

class ConfirmOrderScreen extends StatefulWidget {
  const ConfirmOrderScreen({super.key});

  @override
  State<ConfirmOrderScreen> createState() => _ConfirmOrderScreenState();
}

class _ConfirmOrderScreenState extends State<ConfirmOrderScreen> {
  bool _isLoading = false;
  OrderType _selectedOrderType = OrderType.cash;
  double discountPercent = 0.0;
  final TextEditingController _discountController = TextEditingController();

  Future<void> _placeOrder(user, products) async {
    setState(() => _isLoading = true);

    try {
      final api = ApiService(context);
      final List<Map<String, dynamic>> productList =
          products
              .map<Map<String, dynamic>>(
                (p) => {
                  "product_id": p.id,
                  "qty": p.quantity,
                  "unit": "pcs", // "discount": 0,
                },
              )
              .toList();

      final data = {
        "order_type": _selectedOrderType.value,
        "discount_percent": discountPercent,
        // "order_status": "pending",
        // "GST_amount": 0,
        // // or calculate accordingly
        // "total_discount": 0,
        // // or calculate accordingly
        // "total_amount": products.fold(
        //   0.0,
        //   (sum, item) => sum + item.price * item.quantity,
        // ),
        "customer_id": user?.id ?? 1,
        "product_list": productList,
      };

      final orderData = await api.placeOrder(data);

      if (_selectedOrderType == OrderType.cash) {
        Provider.of<AppProvider>(context, listen: false).clearCart();
        context.goNamed(
          'orderSuccess',
          pathParameters: {'orderId': orderData['order_id'].toString()},
        );
      } else if (_selectedOrderType == OrderType.online) {
        await context.pushNamed(
          'paymentImage',
          extra: {
            'orderId': orderData['order_id'],
            'imageUrl': orderData['image_url'],
          },
        );
      }
    } catch (e) {
      print(e);
      showAppSnackBar(context, "❌ Order failed: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final user = appProvider.user;
    final products = appProvider.selectedProducts;

    double subtotal = products.fold(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    // Apply discount BEFORE GST
    double discountAmount = subtotal * (discountPercent / 100);
    double discountedSubtotal = subtotal - discountAmount;

    // GST
    double gstRate = 0.05;
    double gstAmount = discountedSubtotal * gstRate / (1 + gstRate);
    double baseAmount = discountedSubtotal - gstAmount;

    // Final total
    double total = discountedSubtotal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Order'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 700;

          return Center(
            child: Container(
              width: isWide ? 700 : double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer Info',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Name: ${user?.name}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  Text(
                                    'Phone: ${user?.number}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  Text(
                                    'Address: ${user?.address}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Order Summary',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: products.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final item = products[index];
                              final originalPrice = item.price * item.quantity;
                              final discountedPrice =
                                  originalPrice -
                                  (originalPrice * (discountPercent / 100));
                              final hasDiscount = discountPercent > 0;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.shade100,
                                  child: Text(
                                    item.quantity.toString(),
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                ),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasDiscount) // Show only if discount applied
                                      Text(
                                        '₹ ${originalPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    Text(
                                      '₹ ${hasDiscount ? discountedPrice.toStringAsFixed(2) : originalPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _discountController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: "Discount (%)",
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        discountPercent =
                                            double.tryParse(val) ?? 0.0;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "- ₹ ${discountAmount.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Subtotal:"),
                                    Text("₹ ${subtotal.toStringAsFixed(2)}"),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Discount (${discountPercent.toStringAsFixed(1)}%):",
                                    ),
                                    Text(
                                      "- ₹ ${discountAmount.toStringAsFixed(2)}",
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Taxable Amount:"),
                                    Text("₹ ${baseAmount.toStringAsFixed(2)}"),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("GST (5%):"),
                                    Text("₹ ${gstAmount.toStringAsFixed(2)}"),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Total:",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Text(
                                      "₹ $total",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 12.0,
                              top: 6,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.payment, color: Colors.green),
                                      SizedBox(width: 10),
                                      Text(
                                        "Payment Type:",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  SegmentedButton<OrderType>(
                                    segments:
                                        OrderType.values.map((type) {
                                          return ButtonSegment<OrderType>(
                                            value: type,
                                            label: Text(type.label),
                                            icon: Icon(
                                              type == OrderType.online
                                                  ? Icons.qr_code_2
                                                  : Icons.attach_money_rounded,
                                            ),
                                          );
                                        }).toList(),
                                    selected: <OrderType>{_selectedOrderType},
                                    onSelectionChanged: (newSelection) {
                                      setState(() {
                                        _selectedOrderType = newSelection.first;
                                      });
                                    },
                                    style: ButtonStyle(
                                      backgroundColor:
                                          WidgetStateProperty.resolveWith((
                                            states,
                                          ) {
                                            if (states.contains(
                                              WidgetState.selected,
                                            )) {
                                              return Colors.green.shade200;
                                            }
                                            return Colors.white;
                                          }),
                                      foregroundColor: WidgetStateProperty.all(
                                        Colors.black87,
                                      ),
                                      padding: WidgetStateProperty.all(
                                        const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isLoading
                                  ? null
                                  : () async {
                                    if (_selectedOrderType == OrderType.cash) {
                                      // Show confirmation dialog only for cash orders
                                      // final confirm = await showDialog<bool>(
                                      //   context: context,
                                      //   builder:
                                      //       (_) => AlertDialog(
                                      //         title: const Text("Place Order?"),
                                      //         content: const Text(
                                      //           "Do you want to place this order?",
                                      //         ),
                                      //         actions: [
                                      //           TextButton(
                                      //             onPressed:
                                      //                 () => Navigator.pop(
                                      //                   context,
                                      //                   false,
                                      //                 ),
                                      //             child: const Text("Cancel"),
                                      //           ),
                                      //           TextButton(
                                      //             onPressed:
                                      //                 () => Navigator.pop(
                                      //                   context,
                                      //                   true,
                                      //                 ),
                                      //             child: const Text("Confirm"),
                                      //           ),
                                      //         ],
                                      //       ),
                                      // );
                                      //
                                      // if (confirm ?? false) {
                                      await _placeOrder(user, products);
                                      // }
                                    } else {
                                      // Directly place order or redirect for other order types
                                      await _placeOrder(user, products);
                                    }
                                  },
                          icon: const Icon(Icons.shopping_bag),
                          label: Text(
                            _isLoading ? "Placing Order..." : "Place Order",
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
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
    );
  }
}
