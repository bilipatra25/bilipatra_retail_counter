import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
// import 'dart:html' as html;

class ConfirmOrderScreen extends StatefulWidget {
  const ConfirmOrderScreen({super.key});

  @override
  State<ConfirmOrderScreen> createState() => _ConfirmOrderScreenState();
}

class _ConfirmOrderScreenState extends State<ConfirmOrderScreen> {
  bool _isLoading = false;
  OrderType _selectedOrderType = OrderType.cash;

  Future<void> _placeOrder(user, products) async {
    setState(() => _isLoading = true);

    try {
      final api = ApiService(context);
      final List<Map<String, dynamic>> productList = products
          .map<Map<String, dynamic>>(
            (p) => {
              "product_id": p.id,
              "qty": p.quantity,
              "unit": "pcs",
              // "discount": 0,
            },
          )
          .toList();

      final data = {
        "order_type": _selectedOrderType.value,
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
        context.goNamed(
          'orderSuccess',
          pathParameters: {
            'orderId': orderData['order_id'].toString(),
          },
        );
      } else if (_selectedOrderType == OrderType.online) {
        context.goNamed(
          'paymentImage',
          extra: {
            'orderId': orderData['order_id'],
            'imageUrl': orderData['image_url'],
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unknown order type selected')),
        );
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Order failed: $e")));
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
    double gstAmount = subtotal * 0.05;
    double total = subtotal + gstAmount;

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
                                trailing: Text(
                                  '₹ ${(item.price * item.quantity).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
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
                                    const Text(
                                      'Subtotal:',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    Text(
                                      '₹ ${subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'GST (5%):',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    Text(
                                      '₹ ${gstAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Text(
                                      '₹ ${total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
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
                            padding:
                                const EdgeInsets.only(bottom: 12.0, top: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.payment,
                                      color: Colors.green),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Payment Type:",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<OrderType>(
                                        value: _selectedOrderType,
                                        isExpanded: true,
                                        icon: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                        ),
                                        dropdownColor: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                        onChanged: (OrderType? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              _selectedOrderType = newValue;
                                            });
                                          }
                                        },
                                        items: OrderType.values
                                            .map((OrderType type) {
                                          return DropdownMenuItem<OrderType>(
                                            value: type,
                                            child: Text(type.label),
                                          );
                                        }).toList(),
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
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Place Order?"),
                                      content: const Text(
                                        "Do you want to place this order?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            context,
                                            false,
                                          ),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            context,
                                            true,
                                          ),
                                          child: const Text("Confirm"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm ?? false) {
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
