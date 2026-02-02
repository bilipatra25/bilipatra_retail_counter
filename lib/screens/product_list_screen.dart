import 'package:bilipatra_retail_counter/screens/wholesale_inquiry_bottom_sheet.dart';
import 'package:bilipatra_retail_counter/utils/globals.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/TotalOrderReport.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'PaymentQRPage.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late ApiService _apiService;
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 20;
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  List<ProductModel> _products = [];
  TotalOrderReport? report;
  bool isDashboardLoading = false;
  DateTimeRange? customRange;
  DateFilter _selectedFilter = DateFilter.today;
  @override
  void initState() {
    super.initState();
    _apiService = ApiService(context);
    _loadProducts();
    _scrollController.addListener(_scrollListener);
    _applyFilter(_selectedFilter);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppUpdate();
    });
  }

  Future<void> _checkAppUpdate() async {
    try {
      final config = await _apiService.fetchAppConfig();
      final info = await PackageInfo.fromPlatform();

      final String currentVersion = info.version;
      final String minVersion =
          config['retail_app_minimum_version'] ?? '0.0.0';
      final String latestVersion =
          config['retail_app_version'] ?? '0.0.0';
      final String apkUrl = config['retail_app_url'] ?? '';

      debugPrint(
        '\x1B[34mCurrent: $currentVersion | Min: $minVersion | Latest: $latestVersion\x1B[0m',
      );

      // 🔴 Force update
      if (compareVersions(currentVersion, minVersion) < 0) {
        _showUpdateBottomSheet(
          forceUpdate: true,
          apkUrl: apkUrl,
        );
        return;
      }

      // 🟡 Optional update
      if (compareVersions(currentVersion, latestVersion) < 0) {
        _showUpdateBottomSheet(
          forceUpdate: false,
          apkUrl: apkUrl,
        );
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  int compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map(int.parse).toList();
    final v2Parts = v2.split('.').map(int.parse).toList();

    final maxLength = v1Parts.length > v2Parts.length
        ? v1Parts.length
        : v2Parts.length;

    for (int i = 0; i < maxLength; i++) {
      final v1Part = i < v1Parts.length ? v1Parts[i] : 0;
      final v2Part = i < v2Parts.length ? v2Parts[i] : 0;

      if (v1Part > v2Part) return 1;
      if (v1Part < v2Part) return -1;
    }
    return 0; // equal
  }

  void _showUpdateBottomSheet({
    required bool forceUpdate,
    required String apkUrl,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: !forceUpdate,
      enableDrag: !forceUpdate,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.system_update,
                size: 60,
                color: Colors.green.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                "App Update Available",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                forceUpdate
                    ? "You must update the app to continue using it."
                    : "A new version is available with improvements.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (!forceUpdate)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Later"),
                      ),
                    ),
                  if (!forceUpdate) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openApk(apkUrl),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Update Now"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openApk(String url) async {
    try {
      final uri = Uri.parse(url);

      // First try: open in browser (MOST RELIABLE)
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );

      if (!launched) {
        // Fallback: external app
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint("Failed to open APK url: $e");
      showAppSnackBar(context, "Unable to open update link");
    }
  }

  Future<void> _loadProducts() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final results = await _apiService.productList(_currentPage, _pageSize);
      setState(() {
        _products.addAll(results.cast<ProductModel>());
        _hasMore = results.length == _pageSize;
        _currentPage++;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadProducts();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final selected = appProvider.selectedProducts;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        // white background
        elevation: 0,
        // optional: remove shadow for a clean look
        title: Row(
          children: [
            Image.asset("assets/logo_min.png", height: 32),
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
        iconTheme: const IconThemeData(
          color: Colors.green,
        ), // for menu/drawer icon
      ),
      endDrawer: Drawer(
        backgroundColor: Colors.green.shade50, // lightest green background
        child: SafeArea(
          child:
              isDashboardLoading
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
                              onSelected:
                                  (_) => _applyFilter(DateFilter.yesterday),
                            ),
                            ChoiceChip(
                              label: const Text("This Month"),
                              selected: _selectedFilter == DateFilter.thisMonth,
                              onSelected:
                                  (_) => _applyFilter(DateFilter.thisMonth),
                            ),
                            ChoiceChip(
                              label: const Text("Lifetime"),
                              selected: _selectedFilter == DateFilter.lifetime,
                              onSelected:
                                  (_) => _applyFilter(DateFilter.lifetime),
                            ),
                            ChoiceChip(
                              label: const Text("Custom"),
                              selected: _selectedFilter == DateFilter.custom,
                              onSelected:
                                  (_) => _applyFilter(DateFilter.custom),
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

                        const SizedBox(height: 24),
                        const Divider(),

                        // ✅ New Option: Open Payment QR Activity
                        ListTile(
                          leading: const Icon(
                            Icons.qr_code,
                            color: Colors.green,
                          ),
                          title: const Text(
                            "Open Payment QR",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context); // close drawer first
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PaymentQRPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child:
            _error != null
                ? _buildErrorState(
                  message: _error!,
                  onRetry: _retryLoadProducts,
                )
                : GridView.builder(
                  controller: _scrollController,
                  itemCount: _products.length + (_hasMore ? 1 : 0),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16, // 👈 Adds space at top and bottom
                    horizontal: 4, // optional small side padding
                  ),
                  clipBehavior:
                      Clip.none, // 👈 prevents clipping on scroll edges
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: (MediaQuery.of(context).size.width ~/ 180)
                        .clamp(2, 5),
                    mainAxisExtent: 250,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (_, index) {
                    if (index == _products.length) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final product = _products[index];
                    final isSelected = selected.contains(product);
                    final qty =
                        isSelected
                            ? selected
                                .firstWhere((p) => p.id == product.id)
                                .quantity
                            : 0;

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                product.image,
                                height: 90,
                                width: 90,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => Image.asset(
                                      'assets/images/placeholder.jpg',
                                      height: 90,
                                      width: 90,
                                      fit: BoxFit.cover,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.name,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              product.weight,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹ ${product.price.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            isSelected
                                ? Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.green.shade50,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                        onPressed:
                                            () => appProvider.decrementQuantity(
                                              product,
                                            ),
                                      ),
                                      Text(
                                        '$qty',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        onPressed:
                                            () => appProvider.incrementQuantity(
                                              product,
                                            ),
                                      ),
                                    ],
                                  ),
                                )
                                : ElevatedButton(
                                  onPressed:
                                      () => appProvider.addProduct(product),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'Add to Cart',
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),

      // ✅ Bottom bar (Material standard)
      bottomNavigationBar:
          selected.isEmpty
              ? null
              : Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total: ₹ ${appProvider.totalPrice.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Checkout Button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isLoading
                                      ? null
                                      : () => _placeOrder(selected),
                              icon:
                                  _isLoading
                                      ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : const Icon(
                                        Icons.shopping_cart_checkout_rounded,
                                        size: 20,
                                      ),
                              label: Text(
                                _isLoading ? 'Placing...' : 'Checkout',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                minimumSize: const Size.fromHeight(46),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // User Details Button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/userForm'),
                              icon: const Icon(
                                Icons.person_add_alt,
                                color: Colors.green,
                                size: 20,
                              ),
                              label: Text(
                                'Customer',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                side: BorderSide(
                                  color: Colors.green.shade700,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                minimumSize: const Size.fromHeight(46),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text("Wholesale Inquiry"),
        icon: const Icon(Icons.warehouse),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => WholesaleInquiryBottomSheet(parentContext: context),
          );
        },
      ),
    );
  }

  void _retryLoadProducts() {
    setState(() {
      _error = null;
      _products.clear();
      _currentPage = 1;
      _hasMore = true;
    });
    _loadProducts();
  }

  Widget _buildErrorState({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/placeholder.png', // 👈 add your image here
              height: 160,
            ),
            const SizedBox(height: 20),
            Text(
              "Something went wrong",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _placeOrder(products) async {
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
        "order_type": OrderType.cash.value,
        // "discount_percent":discountPercent,
        "customer_id": 0,
        "product_list": productList,
      };

      final orderData = await api.placeOrder(data);
      Provider.of<AppProvider>(context, listen: false).clearCart();
      context.goNamed(
        'orderSuccess',
        pathParameters: {'orderId': orderData['order_id'].toString()},
      );
    } catch (e) {
      print(e);
      showAppSnackBar(context, "❌ Order failed: $e");
    } finally {
      setState(() => _isLoading = false);
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
        startDate =
            endDate =
                "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
        break;

      case DateFilter.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        startDate =
            endDate =
                "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
        break;

      case DateFilter.thisMonth:
        startDate =
            "${today.year}-${today.month.toString().padLeft(2, '0')}-01";
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
}
