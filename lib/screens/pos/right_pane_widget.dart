import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/cart_item_model.dart';
import '../../models/user.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import 'checkout_service.dart';
import 'qr_payment_dialog.dart';

class RightPaneWidget extends StatefulWidget {
  const RightPaneWidget({super.key});

  @override
  State<RightPaneWidget> createState() => _RightPaneWidgetState();
}

class _RightPaneWidgetState extends State<RightPaneWidget> {
  final TextEditingController _mobileController = TextEditingController();
  bool _isLoadingCustomer = false;
  bool _isProcessingCheckout = false;

  @override
  void dispose() {
    _mobileController.dispose();
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

    setState(() => _isLoadingCustomer = true);

    try {
      final response = await ApiService(context).userSelectByMobileNo(mobile);

      Map<String, dynamic>? customerData;

      // 🟢 Parse your specific API response structure
      if (response['flag'] == 1 &&
          response['code'] == 200 &&
          response['data'] != null) {
        final data = response['data'];
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          customerData = data;
        }
      }

      // 🟢 Always pop the dialog, passing data if they are a repeat customer
      if (mounted) {
        _showCustomerDialog(mobile, provider, customerData);
      }
    } catch (e) {
      debugPrint("API Error fetching customer: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Network error checking customer."),
            backgroundColor: Colors.red,
          ),
        );
        // Fallback: Let them manually enter data if network fails but they still want to try
        _showCustomerDialog(mobile, provider, null);
      }
    } finally {
      setState(() => _isLoadingCustomer = false);
    }
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

    // Auto-fill controllers if data exists
    final TextEditingController nameController = TextEditingController(
      text: isExisting ? existingData['name'] : "",
    );
    final TextEditingController addressController = TextEditingController(
      text: isExisting ? existingData['address'] : "",
    );

    // Extract loyalty stats
    final int ordersCount = isExisting ? (existingData['ordersCount'] ?? 0) : 0;
    final String channel =
        isExisting
            ? (existingData['channel']?.toString().toUpperCase() ?? "UNKNOWN")
            : "";

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🟢 REPEATE CUSTOMER LOYALTY BANNER
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

                    // Input Fields
                    TextField(
                      controller: TextEditingController(text: mobile),
                      enabled: false, // Lock mobile number
                      decoration: InputDecoration(
                        labelText: "Mobile Number",
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.phone),
                        fillColor: Colors.grey.shade100,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      autofocus: !isExisting, // Only autofocus if new
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: "Customer Name *",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: addressController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Address / Area",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving
                          ? null
                          : () {
                            _mobileController.clear();
                            Navigator.pop(context);
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
                  onPressed:
                      isSaving
                          ? null
                          : () async {
                            if (nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("⚠️ Customer Name is required"),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            setDialogState(() => isSaving = true);

                            try {
                              final response = await ApiService(
                                context,
                              ).customerLogin(
                                nameController.text.trim(),
                                mobile,
                                addressController.text.trim(),
                              );

                              if (response['flag'] == 1 ||
                                  response['code'] == 200) {
                                // 🟢 BULLETPROOF ID EXTRACTION
                                int finalCustomerId = provider.defaultWalkInId;

                                // 1. First, check if the insert API returned the new ID
                                if (response['data'] != null) {
                                  if (response['data'] is Map) {
                                    finalCustomerId =
                                        response['data']['insertId'] ??
                                        response['data']['customer_id'] ??
                                        response['data']['id'] ??
                                        finalCustomerId;
                                  } else if (response['data'] is int) {
                                    finalCustomerId =
                                        response['data']; // If backend returns just the number
                                  } else if (response['data'] is String) {
                                    finalCustomerId =
                                        int.tryParse(response['data']) ??
                                        finalCustomerId;
                                  }
                                }

                                // 2. If it's an existing customer and the update API didn't return an ID, pull it from their original fetched data
                                if (isExisting &&
                                    finalCustomerId ==
                                        provider.defaultWalkInId &&
                                    existingData != null) {
                                  finalCustomerId =
                                      existingData['customer_id'] ??
                                      existingData['id'] ??
                                      provider.defaultWalkInId;
                                }

                                // 3. Debug warning if we STILL couldn't find an ID
                                if (finalCustomerId ==
                                    provider.defaultWalkInId) {
                                  debugPrint(
                                    "⚠️ WARNING: Could not find customer ID from backend. Defaulting to 1.",
                                  );
                                }

                                // Assign to cart
                                provider.setCustomer(
                                  UserModel(
                                    id: finalCustomerId,
                                    name: nameController.text.trim(),
                                    number: mobile,
                                    address: addressController.text.trim(),
                                  ),
                                );

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isExisting
                                            ? "✅ Customer details confirmed! (ID: $finalCustomerId)"
                                            : "✅ New Customer Registered! (ID: $finalCustomerId)",
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                throw Exception(
                                  response['message'] ??
                                      "Failed to save details",
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
                              setDialogState(() => isSaving = false);
                            }
                          },
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

  // ==========================================
  // REUSABLE DISCOUNT DIALOG
  // ==========================================
  void _showDiscountDialog({
    required AppProvider provider,
    CartItem? specificItem,
  }) {
    DiscountType initialType =
        specificItem != null
            ? (specificItem.discountType == DiscountType.none
                ? DiscountType.percent
                : specificItem.discountType)
            : (provider.globalDiscountType == DiscountType.none
                ? DiscountType.percent
                : provider.globalDiscountType);

    DiscountBase initialBase =
        specificItem != null
            ? specificItem.discountBase
            : provider.globalDiscountBase;
    double initialValue =
        specificItem != null
            ? specificItem.discountValue
            : provider.globalDiscountValue;

    final TextEditingController discountController = TextEditingController(
      text: initialValue == 0 ? "" : initialValue.toStringAsFixed(0),
    );

    DiscountType selectedType = initialType;
    DiscountBase selectedBase = initialBase;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                specificItem != null
                    ? 'Item Discount: ${specificItem.product.name}'
                    : 'Global Cart Discount',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Discount Type:",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  SegmentedButton<DiscountType>(
                    segments: const [
                      ButtonSegment(
                        value: DiscountType.percent,
                        label: Text("Percent (%)"),
                      ),
                      ButtonSegment(
                        value: DiscountType.flat,
                        label: Text("Flat (₹)"),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged:
                        (newSelection) => setDialogState(
                          () => selectedType = newSelection.first,
                        ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    "Apply On:",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  SegmentedButton<DiscountBase>(
                    segments: const [
                      ButtonSegment(
                        value: DiscountBase.mrp,
                        label: Text("MRP"),
                      ),
                      ButtonSegment(
                        value: DiscountBase.sellingPrice,
                        label: Text("Selling Price"),
                      ),
                    ],
                    selected: {selectedBase},
                    onSelectionChanged:
                        (newSelection) => setDialogState(
                          () => selectedBase = newSelection.first,
                        ),
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: discountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText:
                          selectedType == DiscountType.percent
                              ? 'Discount %'
                              : 'Discount Amount ₹',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (specificItem != null) {
                      provider.applyItemDiscount(
                        specificItem.product,
                        DiscountType.none,
                        0,
                        DiscountBase.sellingPrice,
                      );
                    } else {
                      provider.applyCartDiscount(
                        DiscountType.none,
                        0,
                        DiscountBase.sellingPrice,
                      );
                    }
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Clear / Remove',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final val = double.tryParse(discountController.text) ?? 0;
                    if (specificItem != null) {
                      provider.applyItemDiscount(
                        specificItem.product,
                        val > 0 ? selectedType : DiscountType.none,
                        val,
                        selectedBase,
                      );
                    } else {
                      provider.applyCartDiscount(
                        val > 0 ? selectedType : DiscountType.none,
                        val,
                        selectedBase,
                      );
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final user = appProvider.selectedCustomer;

    return Column(
      children: [
        // 1. CUSTOMER HEADER
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            children: [
              TextField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (val) => _fetchCustomer(val, appProvider),
                decoration: InputDecoration(
                  labelText: "Customer Mobile (Optional)",
                  prefixIcon: const Icon(Icons.phone),
                  suffixIcon:
                      _isLoadingCustomer
                          ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : _mobileController.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _mobileController.clear();
                              appProvider.clearCustomer();
                            },
                          )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              // Verification Badge UI
              if (user != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
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
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "${user.name} ${user.address.isNotEmpty ? '(${user.address})' : ''}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Active Customer",
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 2. ACTIVE CART LIST
        Expanded(
          child:
              appProvider.cart.isEmpty
                  ? Center(
                    child: Text(
                      "Cart is empty",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 18,
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

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          "${item.product.name} (${item.product.weight})",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "₹${item.product.price.toStringAsFixed(0)} x ${item.quantity}",
                            ),
                            if (rowDiscount > 0)
                              InkWell(
                                onTap:
                                    () => _showDiscountDialog(
                                      provider: appProvider,
                                      specificItem: item,
                                    ),
                                child: Text(
                                  "Discount: -₹${rowDiscount.toStringAsFixed(0)} ${item.hasCustomDiscount ? '(Override)' : ''}",
                                  style: TextStyle(
                                    color:
                                        item.hasCustomDiscount
                                            ? Colors.orange.shade700
                                            : Colors.red,
                                    fontWeight: FontWeight.w500,
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
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: Icon(
                                Icons.local_offer_outlined,
                                color:
                                    item.hasCustomDiscount
                                        ? Colors.orange
                                        : Colors.blue,
                              ),
                              tooltip: "Item Override Discount",
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
                              ),
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

        // 3. CHECKOUT FOOTER
        if (appProvider.cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
                    const Text(
                      "Gross Total:",
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    Text(
                      "₹${appProvider.cartSubtotal.toStringAsFixed(2)}",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),

                if (appProvider.cartTotalDiscount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total Discounts:",
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        ),
                        Text(
                          "-₹${appProvider.cartTotalDiscount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Divider(height: 16),

                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed:
                        () => _showDiscountDialog(
                          provider: appProvider,
                          specificItem: null,
                        ),
                    icon: Icon(
                      Icons.style,
                      color:
                          appProvider.globalDiscountValue > 0
                              ? Colors.green
                              : Colors.blueGrey,
                      size: 18,
                    ),
                    label: Text(
                      appProvider.globalDiscountValue > 0
                          ? "Global Discount Active (Tap to edit)"
                          : "Apply Global Cart Discount",
                      style: TextStyle(
                        color:
                            appProvider.globalDiscountValue > 0
                                ? Colors.green
                                : Colors.blueGrey,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Grand Total:",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "₹${appProvider.cartFinalTotal.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isProcessingCheckout
                                ? null
                                : () async {
                                  if (appProvider.cart.isEmpty) return;
                                  setState(() => _isProcessingCheckout = true);
                                  try {
                                    final responseData =
                                        await CheckoutService.placeCashOrder(
                                          context,
                                          appProvider,
                                        );
                                    appProvider.clearCartAndCustomer();
                                    _mobileController.clear();
                                    if (mounted)
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
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.payments),
                        label: Text(
                          _isProcessingCheckout ? "PROCESSING..." : "PAY CASH",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isProcessingCheckout
                                ? null
                                : () async {
                                  if (appProvider.cart.isEmpty) return;
                                  setState(() => _isProcessingCheckout = true);
                                  try {
                                    final responseData =
                                        await CheckoutService.placeOnlineOrder(
                                          context,
                                          appProvider,
                                        );
                                    final orderId = responseData['order_id'];
                                    final grandTotal =
                                        double.tryParse(
                                          responseData['grand_total']
                                              .toString(),
                                        ) ??
                                        0.0;
                                    final qrImageUrl =
                                        responseData['image_url'];
                                    final currentMobile =
                                        _mobileController.text;

                                    if (mounted)
                                      setState(
                                        () => _isProcessingCheckout = false,
                                      );

                                    if (mounted) {
                                      final isPaid = await showDialog<bool>(
                                        context: context,
                                        barrierDismissible: false,
                                        builder:
                                            (context) => QRPaymentDialog(
                                              orderId: orderId,
                                              amount: grandTotal,
                                              qrImageUrl: qrImageUrl,
                                              initialMobile:
                                                  currentMobile.isNotEmpty
                                                      ? currentMobile
                                                      : null,
                                            ),
                                      );

                                      if (isPaid == true) {
                                        appProvider.clearCartAndCustomer();
                                        _mobileController.clear();
                                        if (mounted)
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
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.qr_code_2),
                        label: Text(
                          _isProcessingCheckout ? "PROCESSING..." : "UPI QR",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          backgroundColor: Colors.blueAccent.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
}
