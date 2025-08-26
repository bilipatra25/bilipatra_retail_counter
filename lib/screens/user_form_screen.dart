import 'package:bilipatra_retail_counter/services/api_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/TotalOrderReport.dart';
import '../models/order.dart';
import '../models/order_model.dart';
import '../models/user.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';

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

  TotalOrderReport? report;
  bool isDashboardLoading = false;
  DateTimeRange? customRange;
  DateFilter _selectedFilter = DateFilter.today;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(context);
    Provider.of<AppProvider>(context, listen: false).clearCart();
    _initFcmToken();
    _applyFilter(_selectedFilter);
  }

  void _loadData(String startDate, String endDate) async {
    setState(() {
      isDashboardLoading = true;
    });

    final data = await _apiService.fetchTotalOrderReport(startDate, endDate);

    setState(() {
      report = data;
      isDashboardLoading = false;
    });
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

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Use Existing Customer?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${customer['customer_name']}'),
              Text('Phone: ${customer['mobile_no']}'),
              Text('Address: ${customer['address']}'),
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
          _nameController.text = customer['customer_name'];
          _addressController.text = customer['address'];
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Customer not found')),
      );
    }
  }

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
          context.push('/products');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Login failed')),
          );
        }
      } catch (e, stack) {
        print("❌ Error: $e");
        print(stack);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Something went wrong!")));
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  void _applyFilter(DateFilter filter) async {
    setState(() {
      _selectedFilter = filter;
      isDashboardLoading = true;
    });

    final today = DateTime.now();
    String startDate = "";
    String endDate = "";

    switch (filter) {
      case DateFilter.today:
        startDate = endDate =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
        break;

      case DateFilter.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        startDate = endDate =
        "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
        break;

      case DateFilter.thisMonth:
        startDate = "${today.year}-${today.month.toString().padLeft(2, '0')}-01";
        endDate =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
        break;

      case DateFilter.lifetime:
      // earliest possible start date
        startDate = "2000-01-01";
        endDate =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
        break;

      case DateFilter.custom:
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
          initialDateRange: DateTimeRange(
            start: today.subtract(const Duration(days: 7)),
            end: today,
          ),
        );

        if (picked != null) {
          startDate =
          "${picked.start.year}-${picked.start.month.toString().padLeft(2, '0')}-${picked.start.day.toString().padLeft(2, '0')}";
          endDate =
          "${picked.end.year}-${picked.end.month.toString().padLeft(2, '0')}-${picked.end.day.toString().padLeft(2, '0')}";
        } else {
          setState(() {
            isDashboardLoading = false; // cancel custom selection
          });
          return;
        }
        break;
    }

    _fetchReport(startDate, endDate);
  }

  Future<void> _fetchReport(String start, String end) async {
    final data = await _apiService.fetchTotalOrderReport(start, end);
    setState(() {
      report = data;
      isDashboardLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, // white background
        elevation: 0, // optional: remove shadow for a clean look
        title: Row(
          children: [
            Image.asset(
              "assets/logo_min.png",
              height: 32,
            ),
            const SizedBox(width: 8),
            const Text(
              "Bilipatra Retail Counter",
              style: TextStyle(
                color: Colors.green, // green text
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        iconTheme:
            const IconThemeData(color: Colors.green), // for menu/drawer icon
      ),
      endDrawer: Drawer(
        backgroundColor: Colors.green.shade50, // lightest green background
        child: SafeArea(
          child: isDashboardLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Dashboard",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text("Today"),
                    selected: _selectedFilter == DateFilter.today,
                    onSelected: (_) => _applyFilter(DateFilter.today),
                  ),
                  ChoiceChip(
                    label: const Text("Yesterday"),
                    selected: _selectedFilter == DateFilter.yesterday,
                    onSelected: (_) => _applyFilter(DateFilter.yesterday),
                  ),
                  ChoiceChip(
                    label: const Text("This Month"),
                    selected: _selectedFilter == DateFilter.thisMonth,
                    onSelected: (_) => _applyFilter(DateFilter.thisMonth),
                  ),
                  ChoiceChip(
                    label: const Text("Lifetime"),
                    selected: _selectedFilter == DateFilter.lifetime,
                    onSelected: (_) => _applyFilter(DateFilter.lifetime),
                  ),
                  ChoiceChip(
                    label: const Text("Custom"),
                    selected: _selectedFilter == DateFilter.custom,
                    onSelected: (_) => _applyFilter(DateFilter.custom),
                  ),
                ],
              ),
                      const SizedBox(height: 16),
                      _buildStatCard(
                        title: "Total Orders",
                        value: "${report?.totalOrder ?? 0}",
                        icon: Icons.shopping_cart,
                        color: Colors.orange,
                      ),
                      _buildStatCard(
                        title: "Total Amount",
                        value: "₹ ${report?.totalAmount ?? '0'}",
                        icon: Icons.attach_money,
                        color: Colors.green,
                      ),
                      _buildStatCard(
                        title: "Cash Orders",
                        value:
                            "${report?.cashOrderCount ?? 0} (₹ ${report?.cashAmount ?? '0'})",
                        icon: Icons.payments,
                        color: Colors.blue,
                      ),
                      _buildStatCard(
                        title: "Online Orders",
                        value:
                            "${report?.onlineOrderCount ?? 0} (₹ ${report?.onlineAmount ?? '0'})",
                        icon: Icons.credit_card,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
        ),
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
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _numberController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon:
                                const Icon(Icons.history, color: Colors.green),
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
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : _submitForm,
                          icon: isLoading
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
                          label: Text(
                            isLoading
                                ? 'Please wait...'
                                : 'Continue to Products',
                          ),
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
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color)),
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
                                  const Icon(Icons.phone,
                                      size: 14, color: Colors.grey),
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
                                  const Icon(Icons.location_on,
                                      size: 14, color: Colors.grey),
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
