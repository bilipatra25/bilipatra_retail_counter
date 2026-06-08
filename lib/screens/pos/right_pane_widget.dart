import 'package:bilipatra_retail_counter/models/order_model.dart';
import 'package:bilipatra_retail_counter/screens/pos/customer_dues_dialog.dart';
import 'package:bilipatra_retail_counter/utils/PrinterHelper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/cart_item_model.dart';
import '../../models/user.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import 'checkout_service.dart';
import 'discount_bottom_sheet.dart';
import 'qr_payment_dialog.dart';

class RightPaneWidget extends StatefulWidget {
  const RightPaneWidget({super.key});

  @override
  State<RightPaneWidget> createState() => _RightPaneWidgetState();
}

class _RightPaneWidgetState extends State<RightPaneWidget> {
  final TextEditingController _mobileController = TextEditingController();
  final FocusNode _mobileFocusNode = FocusNode();

  bool _isLoadingCustomer = false;
  bool _isProcessingCheckout = false;
  bool _printReceipt = true;

  @override
  void dispose() {
    _mobileController.dispose();
    _mobileFocusNode.dispose();
    super.dispose();
  }

  // ==========================================
  // LIVE CUSTOMER FETCHING LOGIC
  // ==========================================
  void _fetchCustomer(String mobile, AppProvider provider) async {
    if (mobile.length != 10) {
      provider.clearCustomer();
      return;
    }

    if (_isLoadingCustomer) return;

    setState(() => _isLoadingCustomer = true);

    try {
      final response = await ApiService(context).userSelectByMobileNo(mobile);

      Map<String, dynamic>? customerData;

      if (response['flag'] == 1 &&
          response['code'] == 200 &&
          response['data'] != null) {
        final data = response['data'];
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          customerData = data;
        }
      }

      if (mounted) {
        _showCustomerDialog(mobile, provider, customerData);
      }
    } catch (e) {
      debugPrint("API Error fetching customer: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Network error checking customer."),
            backgroundColor: Colors.red,
          ),
        );
        _showCustomerDialog(mobile, provider, null);
      }
    } finally {
      if (mounted) setState(() => _isLoadingCustomer = false);
    }
  }

  // ==========================================
  // RECENT CUSTOMERS EXTRACTOR
  // ==========================================
  Future<void> _showRecentCustomers(AppProvider provider) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (c) => const Center(
            child: CircularProgressIndicator(color: Colors.green),
          ),
    );

    try {
      final res = await ApiService(context).orderList(1, 50);
      if (!mounted) return;
      Navigator.pop(context);

      if (res['flag'] == 1 && res['data'] != null) {
        final orders = res['data']['result'] as List<dynamic>? ?? [];

        final Map<String, Map<String, dynamic>> uniqueCustomers = {};
        for (var o in orders) {
          final mobile = o['order_mobile_no']?.toString() ?? '';
          final name = o['order_username']?.toString() ?? 'Walk-in';
          if (mobile.isNotEmpty &&
              mobile.length >= 10 &&
              mobile != '0000000000' &&
              !uniqueCustomers.containsKey(mobile)) {
            uniqueCustomers[mobile] = {'name': name, 'mobile': mobile};
          }
        }

        final customerList = uniqueCustomers.values.toList();

        if (customerList.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No recent customers found.")),
          );
          return;
        }

        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.history, color: Colors.blue),
                    SizedBox(width: 8),
                    Text("Recent Customers"),
                  ],
                ),
                content: SizedBox(
                  width: 400,
                  height: 400,
                  child: ListView.separated(
                    itemCount: customerList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (c, i) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: Icon(
                            Icons.person,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        title: Text(
                          customerList[i]['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(customerList[i]['mobile']),
                        onTap: () {
                          Navigator.pop(ctx);
                          _mobileController.text = customerList[i]['mobile'];
                          _mobileFocusNode.unfocus();
                          _fetchCustomer(customerList[i]['mobile'], provider);
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Close"),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Failed to fetch recent customers: $e");
    }
  }

  // ==========================================
  // CHECKOUT GUARDRAIL DIALOG
  // ==========================================
  Future<bool> _promptCustomerBeforeCheckout(AppProvider provider) async {
    if (provider.selectedCustomer != null &&
        provider.selectedCustomer!.number.isNotEmpty &&
        provider.selectedCustomer!.number != '0000000000') {
      return true;
    }

    if (_mobileController.text.length == 10) {
      _fetchCustomer(_mobileController.text, provider);
      return false;
    }

    final TextEditingController tempMobile = TextEditingController();
    final FocusNode tempFocus = FocusNode();

    bool? result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.person_search,
                  color: Colors.orange.shade700,
                  size: 28,
                ),
                const SizedBox(width: 8),
                const Text("Missing Customer Detail"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Are you sure you want to checkout without entering a customer? \n\nEnter mobile to add them, or hit [Enter] to skip.",
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tempMobile,
                  focusNode: tempFocus..requestFocus(),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(10),
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textInputAction: TextInputAction.done,
                  onChanged: (val) {
                    if (val.length == 10) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  onSubmitted: (val) {
                    if (val.length == 10) {
                      Navigator.pop(ctx, true);
                    } else {
                      Navigator.pop(ctx, false);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: "Mobile Number",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text(
                  "Cancel Checkout",
                  style: TextStyle(color: Colors.red),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade600,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Skip & Proceed"),
              ),
            ],
          ),
    );

    if (result == null) return false;
    if (result == false) return true;

    if (result == true) {
      _mobileController.text = tempMobile.text;
      _fetchCustomer(tempMobile.text, provider);
      return false;
    }

    return false;
  }

  // ==========================================
  // 🟢 NEW: CREDIT ADVANCE PAYMENT DIALOG
  // ==========================================
  Future<Map<String, dynamic>?> _showCreditDialog(double grandTotal) async {
    double advanceAmount = 0.0;
    String method = 'cash';
    final TextEditingController advanceCtrl = TextEditingController(text: "0");

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double remaining = grandTotal - advanceAmount;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.menu_book, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  const Text("Pay Later / Credit"),
                ],
              ),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Grand Total:",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "₹${grandTotal.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Advance Payment Received (₹)",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: advanceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          advanceAmount = double.tryParse(val) ?? 0.0;
                          if (advanceAmount > grandTotal) {
                            advanceAmount = grandTotal;
                            advanceCtrl.text = grandTotal.toStringAsFixed(2);
                          }
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.currency_rupee),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    if (advanceAmount > 0) ...[
                      const SizedBox(height: 16),
                      const Text(
                        "Advance Payment Method",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text("Cash"),
                              value: "cash",
                              groupValue: method,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged:
                                  (val) => setDialogState(() => method = val!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text("UPI"),
                              value: "online",
                              groupValue: method,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged:
                                  (val) => setDialogState(() => method = val!),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Remaining Credit:",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          Text(
                            "₹${remaining.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx, {
                      'amount': advanceAmount,
                      'method': method,
                    });
                  },
                  child: const Text("Confirm Credit Order"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // SMART CUSTOMER DIALOG (New & Repeat)
  // ==========================================
  void _showCustomerDialog(
    String mobile,
    AppProvider provider,
    Map<String, dynamic>? existingData,
  ) {
    final isExisting = existingData != null;

    final TextEditingController nameController = TextEditingController(
      text: isExisting ? existingData['name'] : "",
    );
    final TextEditingController addressController = TextEditingController(
      text: isExisting ? existingData['address'] : "",
    );

    final int ordersCount = isExisting ? (existingData['ordersCount'] ?? 0) : 0;
    final String channel =
        isExisting
            ? (existingData['channel']?.toString().toUpperCase() ?? "UNKNOWN")
            : "";

    bool isSaving = false;
    final FocusNode nameFocus = FocusNode();
    final FocusNode addressFocus = FocusNode();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> submitCustomerForm() async {
              if (isSaving) return;
              setDialogState(() => isSaving = true);

              String finalName = nameController.text.trim();
              if (finalName.isEmpty) finalName = "Walk-in Customer";
              String finalAddress = addressController.text.trim();

              try {
                final response = await ApiService(
                  context,
                ).customerLogin(finalName, mobile, finalAddress);

                if (response['flag'] == 1 || response['code'] == 200) {
                  int finalCustomerId = provider.defaultWalkInId;

                  if (response['data'] != null) {
                    if (response['data'] is Map) {
                      finalCustomerId =
                          response['data']['insertId'] ??
                          response['data']['customer_id'] ??
                          response['data']['id'] ??
                          finalCustomerId;
                    } else if (response['data'] is int) {
                      finalCustomerId = response['data'];
                    } else if (response['data'] is String) {
                      finalCustomerId =
                          int.tryParse(response['data']) ?? finalCustomerId;
                    }
                  }

                  if (isExisting &&
                      finalCustomerId == provider.defaultWalkInId &&
                      existingData != null) {
                    finalCustomerId =
                        existingData['customer_id'] ??
                        existingData['id'] ??
                        provider.defaultWalkInId;
                  }

                  provider.setCustomer(
                    UserModel(
                      id: finalCustomerId,
                      name: finalName,
                      number: mobile,
                      address: finalAddress,
                    ),
                  );

                  if (mounted) {
                    Navigator.pop(dialogContext);
                  }
                } else {
                  throw Exception(
                    response['message'] ?? "Failed to save details",
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
              } finally {
                if (mounted) setDialogState(() => isSaving = false);
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isExisting ? Icons.manage_accounts : Icons.person_add,
                    color: isExisting ? Colors.blue : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isExisting
                        ? "Verify Customer Details"
                        : "Register New Customer",
                  ),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isExisting) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.stars,
                                color: Colors.blue,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "REPEATE CUSTOMER",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "$ordersCount Orders  •  Last Channel: $channel",
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      TextField(
                        controller: TextEditingController(text: mobile),
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Mobile Number",
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.phone),
                          fillColor: Colors.grey.shade100,
                          filled: true,
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blueGrey,
                            ),
                            tooltip: "Edit Number",
                            onPressed: () {
                              Navigator.pop(dialogContext); // Close dialog
                              _mobileController.text = mobile;
                              _mobileFocusNode.requestFocus();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        focusNode: nameFocus..requestFocus(),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => addressFocus.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: "Customer Name (Optional)",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: addressController,
                        focusNode: addressFocus,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        maxLines: 1,
                        onSubmitted: (_) {
                          submitCustomerForm();
                        },
                        decoration: const InputDecoration(
                          labelText: "Address / Area (Optional)",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving
                          ? null
                          : () {
                            _mobileController.clear();
                            Navigator.pop(dialogContext);
                          },
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isExisting
                            ? Colors.blue.shade700
                            : Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onPressed: isSaving ? null : submitCustomerForm,
                  icon:
                      isSaving
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Icon(Icons.check_circle),
                  label: Text(
                    isSaving
                        ? "Saving..."
                        : (isExisting ? "Confirm Details" : "Save Customer"),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDiscountDialog({
    required AppProvider provider,
    CartItem? specificItem,
  }) {
    DiscountBottomSheet.show(
      context,
      provider: provider,
      specificItem: specificItem,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final user = appProvider.selectedCustomer;

    return Column(
      children: [
        if (appProvider.isEditingOrder)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.orange.shade300, width: 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.edit_note,
                      color: Colors.orange.shade900,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "EDITING ORDER #${appProvider.editingOrderId}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(
                  height: 30,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      appProvider.clearCartAndCustomer();
                      _mobileController.clear();
                    },
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text(
                      "Cancel",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade700,
                      elevation: 0,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            children: [
              TextField(
                controller: _mobileController,
                focusNode: _mobileFocusNode,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                textInputAction: TextInputAction.search,
                onChanged: (val) {
                  setState(() {});
                  if (val.length == 10) {
                    _mobileFocusNode.unfocus();
                    _fetchCustomer(val, appProvider);
                  }
                },
                onSubmitted: (val) {
                  if (val.length == 10) _fetchCustomer(val, appProvider);
                },
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  labelText: "Customer Mobile (Optional)",
                  prefixIcon: const Icon(Icons.phone, size: 20),
                  suffixIcon:
                      _isLoadingCustomer
                          ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_mobileController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  splashRadius: 20,
                                  onPressed: () {
                                    _mobileController.clear();
                                    appProvider.clearCustomer();
                                    _mobileFocusNode.requestFocus();

                                    setState(() {});
                                  },
                                ),
                              IconButton(
                                icon: Icon(
                                  Icons.manage_search,
                                  color: Colors.blue.shade700,
                                  size: 22,
                                ),
                                tooltip: "Recent Customers",
                                splashRadius: 20,
                                onPressed:
                                    () => _showRecentCustomers(appProvider),
                              ),
                            ],
                          ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              if (user != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8, // Thicker padding
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.verified_user,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${user.name} ${user.address.isNotEmpty ? '(${user.address})' : ''}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 14, // Slightly larger font
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 🟢 NEW: KHATA / DUES BUTTON
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder:
                                (context) => CustomerDuesDialog(customer: user),
                          );
                        },
                        icon: const Icon(
                          Icons.account_balance_wallet,
                          size: 18,
                        ),
                        label: const Text(
                          "Khata",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red.shade800,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.red.shade200),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        Expanded(
          child:
              appProvider.cart.isEmpty
                  ? Center(
                    child: Text(
                      "Cart is empty",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
                  )
                  : ListView.separated(
                    itemCount: appProvider.cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = appProvider.cart[index];
                      final rowDiscount = appProvider.getItemCalculatedDiscount(
                        item,
                      );
                      final rowFinalTotal = appProvider.getItemFinalTotal(item);

                      String discountDetails = "";
                      if (item.hasCustomDiscount) {
                        final valStr = item.discountValue.toStringAsFixed(
                          item.discountValue.truncateToDouble() ==
                                  item.discountValue
                              ? 0
                              : 1,
                        );
                        discountDetails =
                            item.discountType == DiscountType.percent
                                ? "($valStr% Override)"
                                : "(₹$valStr Override)";
                      } else if (appProvider.globalDiscountValue > 0) {
                        final valStr = appProvider.globalDiscountValue
                            .toStringAsFixed(
                              appProvider.globalDiscountValue
                                          .truncateToDouble() ==
                                      appProvider.globalDiscountValue
                                  ? 0
                                  : 1,
                            );

                        final suffix =
                            appProvider.isGlobalDiscountManual
                                ? "Global"
                                : "Qty";
                        discountDetails =
                            appProvider.globalDiscountType ==
                                    DiscountType.percent
                                ? "($valStr% $suffix)"
                                : "(₹$valStr $suffix)";
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          "${item.product.name} (${item.product.weight})",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "₹${item.product.price.toStringAsFixed(0)} x ${item.quantity}",
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (rowDiscount > 0)
                              InkWell(
                                onTap:
                                    () => _showDiscountDialog(
                                      provider: appProvider,
                                      specificItem: item,
                                    ),
                                child: Text(
                                  "Discount: -₹${rowDiscount.toStringAsFixed(0)} $discountDetails",
                                  style: TextStyle(
                                    color:
                                        item.hasCustomDiscount
                                            ? Colors.orange.shade700
                                            : Colors.red,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "₹${rowFinalTotal.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                Icons.local_offer_outlined,
                                color:
                                    item.hasCustomDiscount
                                        ? Colors.orange
                                        : Colors.blue,
                                size: 20,
                              ),
                              splashRadius: 20,
                              onPressed:
                                  () => _showDiscountDialog(
                                    provider: appProvider,
                                    specificItem: item,
                                  ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              splashRadius: 20,
                              onPressed:
                                  () =>
                                      appProvider.removeCartItem(item.product),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),

        if (appProvider.cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (appProvider.globalDiscountValue > 0)
                          GestureDetector(
                            onTap:
                                () => _showDiscountDialog(
                                  provider: appProvider,
                                  specificItem: null,
                                ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    appProvider.isGlobalDiscountManual
                                        ? Colors.orange.shade100
                                        : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      appProvider.isGlobalDiscountManual
                                          ? Colors.orange.shade300
                                          : Colors.green.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.stars,
                                    size: 14,
                                    color:
                                        appProvider.isGlobalDiscountManual
                                            ? Colors.orange.shade800
                                            : Colors.green.shade800,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    appProvider.isGlobalDiscountManual
                                        ? "GLOBAL ${appProvider.globalDiscountType == DiscountType.percent ? '${appProvider.globalDiscountValue.toStringAsFixed(0)}%' : '₹${appProvider.globalDiscountValue.toStringAsFixed(0)}'}"
                                        : "AUTO QTY ${appProvider.globalDiscountValue.toStringAsFixed(0)}%",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          appProvider.isGlobalDiscountManual
                                              ? Colors.orange.shade900
                                              : Colors.green.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          InkWell(
                            onTap:
                                () => _showDiscountDialog(
                                  provider: appProvider,
                                  specificItem: null,
                                ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.style,
                                  color: Colors.blueGrey,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "Add Global Discount",
                                  style: TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 13,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (appProvider.isGlobalDiscountManual)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: SizedBox(
                              height: 24,
                              child: ElevatedButton(
                                onPressed: () {
                                  appProvider.applyCartDiscount(
                                    DiscountType.none,
                                    0,
                                    DiscountBase.sellingPrice,
                                    isManual: false,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: const Text("RESET TO AUTO"),
                              ),
                            ),
                          ),

                        if (appProvider.globalDiscountValue > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: SizedBox(
                              height: 24,
                              child: ElevatedButton(
                                onPressed: () {
                                  appProvider.applyCartDiscount(
                                    DiscountType.none,
                                    0,
                                    DiscountBase.sellingPrice,
                                    isManual: true,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: const Text("CLEAR"),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      "Gross: ₹${appProvider.cartSubtotal.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                if (appProvider.cartTotalDiscount > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "Discounts: -₹${appProvider.cartTotalDiscount.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                const Divider(height: 12),

                // ==========================================
                // 🟢 DYNAMIC TOTALS & SLEEK PRINT TOGGLE
                // ==========================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _printReceipt = !_printReceipt);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _printReceipt
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                _printReceipt
                                    ? Colors.blue.shade300
                                    : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _printReceipt
                                  ? Icons.print
                                  : Icons.print_disabled,
                              size: 16,
                              color:
                                  _printReceipt
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _printReceipt ? "Print: ON" : "Print: OFF",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    _printReceipt
                                        ? Colors.blue.shade700
                                        : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (appProvider.isEditingOrder &&
                            appProvider.previouslyPaidAmount > 0) ...[
                          Text(
                            "Prev Paid: ₹${appProvider.previouslyPaidAmount.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            appProvider.balanceDue >= 0
                                ? "Balance Due:"
                                : "Refund Due:",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color:
                                  appProvider.balanceDue >= 0
                                      ? Colors.orange.shade800
                                      : Colors.red.shade800,
                            ),
                          ),
                          Text(
                            "₹${appProvider.balanceDue.abs().toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color:
                                  appProvider.balanceDue >= 0
                                      ? Colors.orange.shade800
                                      : Colors.red.shade800,
                            ),
                          ),
                        ] else ...[
                          const Text(
                            "Grand Total:",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "₹${appProvider.cartFinalTotal.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ==========================================
                // 🟢 SQUASHED CHECKOUT BUTTONS
                // ==========================================
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isProcessingCheckout
                                ? null
                                : () async {
                                  if (appProvider.cart.isEmpty) return;

                                  if (!await _promptCustomerBeforeCheckout(
                                    appProvider,
                                  ))
                                    return;

                                  setState(() => _isProcessingCheckout = true);
                                  try {
                                    final responseData =
                                        await CheckoutService.placeCashOrder(
                                          context,
                                          appProvider,
                                        );

                                    if (responseData.containsKey(
                                      'action_required',
                                    )) {
                                      final action =
                                          responseData['action_required'];
                                      final delta =
                                          double.tryParse(
                                            responseData['delta_amount']
                                                    ?.toString() ??
                                                '0',
                                          ) ??
                                          0.0;

                                      if (action == 'refund_online_auto') {
                                        if (mounted) {
                                          _showAutoRefundSuccessDialog(
                                            context,
                                            delta.abs(),
                                          );
                                        }
                                      } else if (action == 'refund_manual' ||
                                          action == 'refund') {
                                        _showRefundAlert(context, delta.abs());
                                      } else if (action == 'collect') {
                                        if (mounted) {
                                          _showCollectCashDialog(
                                            context,
                                            delta,
                                          );
                                        }
                                      }
                                    }

                                    appProvider.clearCartAndCustomer();
                                    _mobileController.clear();

                                    final orderIdToPrint =
                                        responseData['order_id'] ??
                                        appProvider.editingOrderId;

                                    if (_printReceipt &&
                                        orderIdToPrint != null) {
                                      _fetchAndPrintOrder(
                                        int.parse(orderIdToPrint.toString()),
                                      );
                                    }

                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "✅ Checkout Successful!",
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "❌ Checkout Failed: $e",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                  } finally {
                                    if (mounted)
                                      setState(
                                        () => _isProcessingCheckout = false,
                                      );
                                  }
                                },
                        icon:
                            _isProcessingCheckout
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.payments, size: 20),
                        label: Text(
                          _isProcessingCheckout
                              ? "WAIT..."
                              : (appProvider.isEditingOrder
                                  ? "UPDATE (CASH)"
                                  : "PAY CASH"),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isProcessingCheckout
                                ? null
                                : () async {
                                  if (appProvider.cart.isEmpty) return;

                                  if (!await _promptCustomerBeforeCheckout(
                                    appProvider,
                                  ))
                                    return;

                                  setState(() => _isProcessingCheckout = true);
                                  try {
                                    final responseData =
                                        await CheckoutService.placeOnlineOrder(
                                          context,
                                          appProvider,
                                        );
                                    final orderId = responseData['order_id'];

                                    bool showQrDialog = true;
                                    double amountToAsk =
                                        double.tryParse(
                                          responseData['grand_total']
                                                  ?.toString() ??
                                              '0',
                                        ) ??
                                        0.0;

                                    if (responseData.containsKey(
                                      'action_required',
                                    )) {
                                      final action =
                                          responseData['action_required'];
                                      final delta =
                                          double.tryParse(
                                            responseData['delta_amount']
                                                    ?.toString() ??
                                                '0',
                                          ) ??
                                          0.0;

                                      if (action == 'refund_online_auto') {
                                        showQrDialog = false;
                                        if (mounted) {
                                          _showAutoRefundSuccessDialog(
                                            context,
                                            delta.abs(),
                                          );
                                        }
                                      } else if (action == 'refund_manual' ||
                                          action == 'refund') {
                                        showQrDialog = false;
                                        _showRefundAlert(context, delta.abs());
                                      } else if (action == 'none') {
                                        showQrDialog = false;
                                      } else if (action == 'collect') {
                                        amountToAsk = delta;
                                      }
                                    }

                                    if (mounted)
                                      setState(
                                        () => _isProcessingCheckout = false,
                                      );

                                    if (showQrDialog) {
                                      final qrImageUrl =
                                          responseData['image_url'];
                                      if (mounted) {
                                        final result = await showDialog<
                                          dynamic
                                        >(
                                          context: context,
                                          barrierDismissible: false,
                                          builder:
                                              (context) => QRPaymentDialog(
                                                orderId: orderId,
                                                amount: amountToAsk,
                                                qrImageUrl: qrImageUrl,
                                                willPrint: _printReceipt,
                                                customerMobile:
                                                    appProvider
                                                        .selectedCustomer
                                                        ?.number,
                                                onPrint: () {
                                                  final orderIdToPrint =
                                                      responseData['order_id'] ??
                                                      appProvider
                                                          .editingOrderId;
                                                  if (orderIdToPrint != null) {
                                                    _fetchAndPrintOrder(
                                                      int.parse(
                                                        orderIdToPrint
                                                            .toString(),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                        );

                                        if (result == 'paid_no_print' ||
                                            result == 'paid_print' ||
                                            result == 'paid_force' ||
                                            result == 'paid' ||
                                            result == true) {
                                          appProvider.clearCartAndCustomer();
                                          _mobileController.clear();

                                          final orderIdToPrint =
                                              responseData['order_id'] ??
                                              appProvider.editingOrderId;

                                          if (orderIdToPrint != null) {
                                            if (result == 'paid_print') {
                                              _fetchAndPrintOrder(
                                                int.parse(
                                                  orderIdToPrint.toString(),
                                                ),
                                              );
                                            } else if (result == 'paid_force' &&
                                                _printReceipt) {
                                              _fetchAndPrintOrder(
                                                int.parse(
                                                  orderIdToPrint.toString(),
                                                ),
                                              );
                                            }
                                          }

                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "✅ Online Order Completed!",
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } else if (result == 'cancel_order') {
                                          try {
                                            await ApiService(
                                              context,
                                            ).cancelOrder(orderId);
                                            appProvider.clearCartAndCustomer();
                                            _mobileController.clear();
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    "🚫 Order Cancelled Entirely",
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    "❌ Failed to cancel order: $e",
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      }
                                    } else {
                                      appProvider.clearCartAndCustomer();
                                      _mobileController.clear();
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "✅ Order Updated Successfully!",
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text("❌ Failed: $e"),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    if (mounted)
                                      setState(
                                        () => _isProcessingCheckout = false,
                                      );
                                  }
                                },
                        icon:
                            _isProcessingCheckout
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.qr_code_2, size: 20),
                        label: Text(
                          _isProcessingCheckout
                              ? "WAIT..."
                              : (appProvider.isEditingOrder
                                  ? "UPDATE (UPI)"
                                  : "UPI QR"),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.blueAccent.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // ==========================================
                    // 🟢 NEW: PAY LATER / CREDIT BUTTON
                    // ==========================================
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isProcessingCheckout
                                ? null
                                : () async {
                                  if (appProvider.cart.isEmpty) return;

                                  // 1. MUST HAVE A REGISTERED CUSTOMER
                                  if (appProvider.selectedCustomer == null ||
                                      appProvider
                                          .selectedCustomer!
                                          .number
                                          .isEmpty ||
                                      appProvider.selectedCustomer!.number ==
                                          '0000000000') {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "⚠️ Please register/select a customer for Credit orders.",
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    _mobileFocusNode.requestFocus();
                                    return;
                                  }

                                  // 2. SHOW PARTIAL PAYMENT DIALOG
                                  final creditData = await _showCreditDialog(
                                    appProvider.cartFinalTotal,
                                  );
                                  if (creditData == null) return; // Cancelled

                                  setState(() => _isProcessingCheckout = true);
                                  try {
                                    final responseData =
                                        await CheckoutService.placeCreditOrder(
                                          context,
                                          appProvider,
                                          creditData['amount'],
                                          creditData['method'],
                                        );

                                    // 3. IF UPI ADVANCE > 0, SHOW QR DIALOG
                                    if (creditData['method'] == 'online' &&
                                        creditData['amount'] > 0) {
                                      // 🔥 SAFE PARSING: Ensure orderId is explicitly an int
                                      final int orderId =
                                          int.tryParse(
                                            responseData['order_id'].toString(),
                                          ) ??
                                          0;
                                      final qrImageUrl =
                                          responseData['image_url'];

                                      if (mounted)
                                        setState(
                                          () => _isProcessingCheckout = false,
                                        );

                                      if (mounted && orderId > 0) {
                                        // Safety check
                                        final result = await showDialog<
                                          dynamic
                                        >(
                                          context: context,
                                          barrierDismissible: false,
                                          builder:
                                              (context) => QRPaymentDialog(
                                                orderId:
                                                    orderId, // 🔥 Passes clean INT
                                                amount: creditData['amount'],
                                                qrImageUrl: qrImageUrl,
                                                willPrint: _printReceipt,
                                                customerMobile:
                                                    appProvider
                                                        .selectedCustomer
                                                        ?.number,
                                                onPrint: () {
                                                  _fetchAndPrintOrder(orderId);
                                                },
                                              ),
                                        );

                                        // Cleanup after QR flow
                                        if (result == 'paid_no_print' ||
                                            result == 'paid_print' ||
                                            result == 'paid_force' ||
                                            result == 'paid' ||
                                            result == true) {
                                          appProvider.clearCartAndCustomer();
                                          _mobileController.clear();
                                          if (result == 'paid_print') {
                                            _fetchAndPrintOrder(orderId);
                                          }
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "✅ Credit Order Saved & UPI Advance Paid!",
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } else if (result == 'cancel_order') {
                                          await ApiService(
                                            context,
                                          ).cancelOrder(orderId);
                                          appProvider.clearCartAndCustomer();
                                          _mobileController.clear();
                                        }
                                      }
                                    }
                                    // 4. CASH ADVANCE OR NO ADVANCE
                                    else {
                                      appProvider.clearCartAndCustomer();
                                      _mobileController.clear();

                                      final orderIdToPrint =
                                          responseData['order_id'] ??
                                          appProvider.editingOrderId;
                                      if (_printReceipt &&
                                          orderIdToPrint != null) {
                                        _fetchAndPrintOrder(
                                          int.parse(orderIdToPrint.toString()),
                                        );
                                      }

                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "✅ Credit Order Saved Successfully!",
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "❌ Checkout Failed: $e",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted)
                                      setState(
                                        () => _isProcessingCheckout = false,
                                      );
                                  }
                                },
                        icon:
                            _isProcessingCheckout
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.menu_book, size: 20),
                        label: Text(
                          _isProcessingCheckout ? "WAIT..." : "PAY LATER",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showRefundAlert(BuildContext context, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 48,
            ),
            title: const Text("Refund Required"),
            content: Text(
              "This updated order is cheaper than the original.\n\nPlease refund ₹${amount.toStringAsFixed(2)} to the customer.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "I have refunded the amount",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  void _showAutoRefundSuccessDialog(BuildContext context, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
            title: const Text("Instant Refund Initiated"),
            content: Text(
              "₹${amount.toStringAsFixed(2)} has been successfully refunded to the customer's bank account.\n\nA confirmation WhatsApp message has been sent to them.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Done",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
    );
  }

  void _showCollectCashDialog(BuildContext context, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: Icon(Icons.add_card, color: Colors.orange.shade700, size: 60),
            title: const Text("Collect Additional Cash"),
            content: Text(
              "The updated order total is higher than the original.\n\nPlease collect an extra ₹${amount.toStringAsFixed(2)} in CASH from the customer.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "I have collected the cash",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _fetchAndPrintOrder(int orderId) async {
    try {
      final res = await ApiService(context).orderListById(orderId.toString());
      if (res['flag'] == 1 && res['data'] != null) {
        OrderModelResponse order = OrderModelResponse.fromJson(res['data']);
        order.orderId = orderId.toString();

        await PrinterHelper.printInvoice(order);
      }
    } catch (e) {
      debugPrint("Auto-print failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "⚠️ Order successful, but print failed: No Default Printer Configured.",
            ),
            backgroundColor: Colors.orange.shade900,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'DISMISS',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }
}
