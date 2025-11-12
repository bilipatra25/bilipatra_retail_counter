import 'package:bilipatra_retail_counter/services/api_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../models/user.dart';
import '../providers/app_provider.dart';
import '../utils/globals.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _addressController = TextEditingController();
  late ApiService _apiService;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(context);
    // Provider.of<AppProvider>(context, listen: false).clearCart();
    _initFcmToken();
  }

  Future<String> getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.id ?? 'unknown';
  }

  void _initFcmToken() async {
    String deviceId = await getDeviceId(); // Await and use this value
    String? token = await FirebaseMessaging.instance.getToken();

    if (token != null) {
      await saveFcmToken(
        deviceId: deviceId,
        fcmToken: token,
        platform: "android",
      );
    }
  }

  Future<void> saveFcmToken({
    required String deviceId,
    required String fcmToken,
    required String platform,
  }) async {
    try {
      final response = await ApiService(
        context,
      ).saveFcmToken(deviceId, fcmToken, platform);

      if (response['flag'] == 1) {
        print('✅ FCM token saved successfully');
      } else {
        print('❌ Failed to save FCM token: ${response['message']}');
        // print(response.body);
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  List<Order> recentOrders = [];

  Future<List<Order>> _fetchRecentOrders() async {
    try {
      final api = ApiService(context);
      final res = await api.orderList(1, 3); // page, limit
      if (res['flag'] == 1 && res['data'] != null) {
        final resultList = res['data']['result'] as List;
        return resultList.map((e) => Order.fromJson(e)).toList();
      }
    } catch (e) {
      print("❌ Error loading orders: $e");
    }
    return [];
  }

  Future<void> fetchCustomerByMobile(String mobile) async {
    if (mobile.length != 10) return;

    final response = await _apiService.userSelectByMobileNo(
      _numberController.text.trim(),
    );

    if (response['flag'] == 1 &&
        response['data'] != null &&
        response['data'].isNotEmpty) {
      final customer = response['data'][0];

      // Handle nulls safely
      final customerName = customer['customer_name'] ?? 'N/A';
      final customerMobile = customer['mobile_no'] ?? 'N/A';
      final customerAddress = customer['address'] ?? 'N/A';
      final totalOrders = customer['total_orders'] ?? 0;
      final isRepeat = totalOrders > 0;

      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Use Existing Customer?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: $customerName'),
                  Text('Phone: $customerMobile'),
                  Text('Address: $customerAddress'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        isRepeat
                            ? 'Repeat Customer ($totalOrders orders)'
                            : 'New Customer',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isRepeat ? Colors.red : Colors.green,
                        ),
                      ),
                      if (isRepeat)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.star, color: Colors.red, size: 18),
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ],
            ),
      );

      if (confirmed == true) {
        setState(() {
          _nameController.text = customerName;
          _addressController.text = customerAddress;
        });
      }
    } else {
      showAppSnackBar(context, response['message'] ?? 'Customer not found');
    }
  }

  // void _skipToProducts() {
  //   // Create a temporary "Quick Customer" UserModel
  //   final quickCustomer = UserModel(
  //     id: 0, // temporary ID (not from API)
  //     name: 'Quick Customer',
  //     number: '99999${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
  //     address: 'Quick Checkout',
  //   );
  //
  //   // Store in Provider just like the normal login flow
  //   Provider.of<AppProvider>(context, listen: false).setUser(quickCustomer);
  //
  //   // Optionally show a small toast/snackbar
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text('Quick Checkout mode enabled')),
  //   );
  //
  //   // Navigate directly to Product Page
  //   context.push('/products');
  // }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);
      try {
        final response = await _apiService.customerLogin(
          _nameController.text.trim(),
          _numberController.text.trim(),
          _addressController.text.trim(),
        );

        if (response['flag'] == 1 && response['data'] != null) {
          final user = UserModel.fromJson(response['data']);
          Provider.of<AppProvider>(context, listen: false).setUser(user);
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text(response['message'] ?? 'Login Successful')),
          // );
          context.push('/confirm');
        } else {
          showAppSnackBar(context, response['message'] ?? 'Login failed');
        }
      } catch (e, stack) {
        print("❌ Error: $e");
        print(stack);
        showAppSnackBar(context, "Something went wrong!");
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;

          return Center(
            child: Container(
              width: isWide ? 600 : double.infinity,
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 12),
                ],
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Customer Details',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _numberController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.history,
                              color: Colors.green,
                            ),
                            tooltip: "View recent customers",
                            onPressed: _showRecentCustomersBottomSheet,
                          ),
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(10),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          fetchCustomerByMobile(value);
                        },
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Required'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Required'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Required'
                                    : null,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : _submitForm,
                          icon:
                              isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Icon(Icons.arrow_forward),
                          label: Text(isLoading ? 'Please wait...' : 'Submit'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Custom widget for statistic card
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRecentCustomersBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return FutureBuilder<List<Order>>(
          future: _fetchRecentOrders(), // Fetch on open
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildBottomSheetContent(
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            } else if (snapshot.hasError) {
              return _buildBottomSheetContent(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.error_outline, color: Colors.red, size: 40),
                      SizedBox(height: 10),
                      Text("Failed to load recent customers"),
                    ],
                  ),
                ),
              );
            } else if (snapshot.data == null || snapshot.data!.isEmpty) {
              return _buildBottomSheetContent(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.people_outline, color: Colors.grey, size: 40),
                      SizedBox(height: 10),
                      Text("No recent customers found"),
                    ],
                  ),
                ),
              );
            }

            final orders = snapshot.data!;
            return _buildBottomSheetContent(
              child: Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final customer = orders[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          _nameController.text = customer.orderUsername;
                          _numberController.text = customer.orderMobileNo;
                          _addressController.text = customer.orderAddress;
                          Navigator.pop(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name & Amount
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      customer.orderUsername,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    "₹${customer.totalAmount}",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Phone
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    customer.orderMobileNo,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Address
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      customer.orderAddress,
                                      style: const TextStyle(fontSize: 13),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomSheetContent({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Recent Customers",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
