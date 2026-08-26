import 'package:bilipatra_retail_counter/screens/pos/payment_qr_page.dart';
import 'package:bilipatra_retail_counter/screens/pos/recent_bills_modal.dart';
import 'package:bilipatra_retail_counter/screens/pos/right_pane_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/cart_item_model.dart';
import '../../models/free_product_offer_model.dart';
import '../../providers/app_provider.dart';
import 'package:package_info_plus/package_info_plus.dart'; // 🟢 Added this import
import '../wholesale_inquiry_bottom_sheet.dart';
import 'admin_dashboard_modal.dart';
import 'app_update_helper.dart';
import 'dashboard_view.dart';
import 'left_pane_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class PosDashboardScreen extends StatefulWidget {
  const PosDashboardScreen({super.key});

  @override
  State<PosDashboardScreen> createState() => _PosDashboardScreenState();
}

class _PosDashboardScreenState extends State<PosDashboardScreen> {
  String _currentVersion = ""; // 🟢 Variable to hold the version

  @override
  void initState() {
    super.initState();
    _loadAppVersion(); // 🟢 Fetch version on load

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateHelper.checkAppUpdate(context);
      _loadGlobalConfigs();
    });
  }

  // 🟢 Helper to get version from platform
  Future<void> _loadGlobalConfigs() async {
    try {
      final apiService = ApiService(context);
      final configRes = await apiService.getConfigurations();
      final offerRes = await apiService.getFreeProductOffers();
      debugPrint("Loaded Configs: $configRes");
      debugPrint("Loaded Offers: $offerRes");

      if ((configRes["code"] == 200 || configRes["flag"] == 1) && configRes["data"] != null) {
        dynamic rawData = configRes["data"];
        List configs = [];
        if (rawData is Map && rawData["result"] != null) {
          configs = rawData["result"];
        } else if (rawData is List) {
          configs = rawData;
        }

        bool autoDiscount = false;
        DiscountBase base = DiscountBase.sellingPrice;
        for (var cfg in configs) {
          if (cfg["configuration_key"] == "enable_auto_discount") {
            final val = cfg["configuration_value"]?.toString().trim();
            autoDiscount = (val == "1" || val == "true");
          }
          if (cfg["configuration_key"] == "default_discount_base") {
            final val = cfg["configuration_value"]?.toString().trim().toLowerCase();
            base = val == "mrp" ? DiscountBase.mrp : DiscountBase.sellingPrice;
          }
        }
        debugPrint("🟢 Parsed autoDiscount: $autoDiscount, base: $base");
        Provider.of<AppProvider>(context, listen: false).setGlobalConfigs(autoDiscount, base);
      }

      if ((offerRes["code"] == 200 || offerRes["flag"] == 1) && offerRes["data"] != null) {
        final List<FreeProductOffer> parsedOffers = (offerRes["data"] as List)
            .map((o) => FreeProductOffer.fromJson(o))
            .toList();
        debugPrint("Parsed Offers Count: ${parsedOffers.length}");
        Provider.of<AppProvider>(context, listen: false).setFreeOffers(parsedOffers);
      }
    } catch (e, stack) {
      debugPrint("Error loading configs: $e");
      debugPrint(stack.toString());
    }
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _currentVersion = info.version;
      });
    }
  }

  // 🟢 Helper function to launch the WebView
  void _openAdminDashboard(BuildContext context) async {
    const String adminMobile = "9974882009";
    const String adminPassword = "vraj@123";
    // Point this one to the main dashboard / orderList
    final String targetUrl =
        'https://retail-counter.bilipatra.com/login?username=$adminMobile&password=$adminPassword&redirect=/admin/orderList';

    if (kIsWeb) {
      // WebView iframe is usually blocked by X-Frame-Options on web, so open in a new tab
      final uri = Uri.parse(targetUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AdminDashboardModal(
              url: targetUrl,
              title: "Admin Dashboard", // Title for the main dashboard
            ),
      );
    }
  }

  // ==========================================
  // 🟢 NEW: STATIC BACKUP QR DIALOG
  // ==========================================
  void _showStaticQR(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user, color: Colors.green, size: 28),
                      SizedBox(width: 10),
                      Text(
                        "Store UPI QR",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Scan to pay directly via PhonePe, GPay, or Paytm.",
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // 🟢 The Static S3 Image
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        'https://b12green-food.s3.ap-south-1.amazonaws.com/development/StaticQRcode.jpeg',
                        width: 300,
                        height: 300,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            width: 300,
                            height: 300,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.green,
                              ),
                            ),
                          );
                        },
                        errorBuilder:
                            (context, error, stackTrace) => Container(
                              width: 300,
                              height: 300,
                              color: Colors.grey.shade100,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Failed to load QR",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text(
                        "Close Screen",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          crossAxisAlignment:
              CrossAxisAlignment.center, // Centers the image with the text
          children: [
            // 🟢 FIXED: Replaced Storefront Icon with Bilipatra Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(
                6,
              ), // Optional: rounds the logo corners slightly
              child: Image.asset(
                'assets/logo.png',
                height: 32,
                width: 32,
                fit: BoxFit.fitWidth,
                errorBuilder:
                    (context, error, stackTrace) => const Icon(
                      Icons.storefront,
                      color: Colors.green,
                      size: 28,
                    ), // Fallback just in case
              ),
            ),
            const SizedBox(width: 6),

            // 🟢 FIXED: Nested Row specifically for perfect baseline text alignment
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  "Bilipatra Retail POS",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 8),
                // DISPLAY VERSION HERE
                Text(
                  "v$_currentVersion",
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // 🟢 NEW: Dashboard Analytics Button
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        // Wrap in a constrained box so it looks great on tablets
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.85,
                            maxHeight:
                                MediaQuery.of(context).size.height * 0.85,
                          ),
                          // 🟢 Call your new Dashboard View here!
                          child: const DashboardView(),
                        ),
                      ),
                    ),
              );
            },
            icon: Icon(Icons.analytics, color: Colors.purple.shade700),
            label: Text(
              "Dashboard",
              style: TextStyle(
                color: Colors.purple.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 🟢 NEW: Admin Dashboard Button
          TextButton.icon(
            onPressed: () => _openAdminDashboard(context),
            icon: Icon(Icons.admin_panel_settings, color: Colors.blue.shade700),
            label: Text(
              "Admin",
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),

          TextButton.icon(
            onPressed: () {
              // Push the Live QR page over the current screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PaymentQRPage()),
              );
            },
            icon: Icon(Icons.cast_connected, color: Colors.orange.shade700),
            label: Text(
              "Live QR Screen",
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ==========================================
          // 🟢 NEW: STATIC BACKUP QR BUTTON
          // ==========================================
          TextButton.icon(
            onPressed: () => _showStaticQR(context),
            icon: Icon(Icons.qr_code_scanner, color: Colors.teal.shade700),
            label: Text(
              "Store QR",
              style: TextStyle(
                color: Colors.teal.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Future: Wholesale Inquiry Button
          TextButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder:
                    (_) => WholesaleInquiryBottomSheet(parentContext: context),
              );
            },
            icon: const Icon(Icons.warehouse, color: Colors.green),
            label: const Text(
              "Wholesale",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Future: Recent Bills / Order History
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const RecentBillsModal(),
              );
            },
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            label: const Text(
              "Recent Bills",
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade700,
            ),
          ),
          const SizedBox(width: 16),
          
          // 🟢 NEW: Logout Button
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Logout"),
                  content: const Text("Are you sure you want to log out?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Logout", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              
              if (confirm == true && context.mounted) {
                // Ignore the lint error for context.read by using provider correctly
                context.read<AuthProvider>().logout();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // ==========================================
          // LEFT PANE (60%) - Product Discovery & Grid
          // ==========================================
          Expanded(flex: 6, child: const LeftPaneWidget()),

          // Divider between the panes
          const VerticalDivider(width: 1, thickness: 1, color: Colors.black12),

          // ==========================================
          // RIGHT PANE (40%) - Customer, Cart & Checkout
          // ==========================================
          Expanded(flex: 4, child: const RightPaneWidget()),
        ],
      ),
    );
  }
}


