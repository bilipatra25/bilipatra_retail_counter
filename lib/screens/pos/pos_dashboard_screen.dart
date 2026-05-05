import 'package:bilipatra_retail_counter/screens/pos/payment_qr_page.dart';
import 'package:bilipatra_retail_counter/screens/pos/recent_bills_modal.dart';
import 'package:bilipatra_retail_counter/screens/pos/right_pane_widget.dart';
import 'package:flutter/material.dart';
// Inside pos_dashboard_screen.dart
import '../wholesale_inquiry_bottom_sheet.dart';
import 'admin_dashboard_modal.dart';
import 'dashboard_view.dart';
import 'left_pane_widget.dart'; // Import it
import 'package:url_launcher/url_launcher.dart'; // 🟢 Added url_launcher

class PosDashboardScreen extends StatelessWidget {
  const PosDashboardScreen({super.key});

  // 🟢 Helper function to launch the WebView
  void _openAdminDashboard(BuildContext context) {
    const String adminMobile = "9974882009";
    const String adminPassword = "vraj@123";
    // Point this one to the main dashboard / orderList
    final String targetUrl = 'https://retail-counter.bilipatra.com/login?username=$adminMobile&password=$adminPassword&redirect=/admin/orderList';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdminDashboardModal(
        url: targetUrl,
        title: "Admin Dashboard", // Title for the main dashboard
      ),
    );
  }

  // ==========================================
  // 🟢 NEW: STATIC BACKUP QR DIALOG
  // ==========================================
  void _showStaticQR(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
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
                        child: Center(child: CircularProgressIndicator(color: Colors.green)),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 300,
                      height: 300,
                      color: Colors.grey.shade100,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 50, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text("Failed to load QR", style: TextStyle(color: Colors.grey)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text("Close Screen", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          children: [
            // Replace with your actual logo asset
            const Icon(Icons.storefront, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            const Text(
              "Bilipatra Retail POS",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          // 🟢 NEW: Dashboard Analytics Button
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    // Wrap in a constrained box so it looks great on tablets
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.85,
                        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                MaterialPageRoute(
                  builder: (context) => const PaymentQRPage(),
                ),
              );
              // Note: If you strictly use GoRouter, replace the Navigator.push with:
              // context.push('/paymentQR'); (or whatever your route name is)
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
        ],
      ),
      body: Row(
        children: [
          // ==========================================
          // LEFT PANE (60%) - Product Discovery & Grid
          // ==========================================
          Expanded(
            flex: 6,
            child: const LeftPaneWidget(), // <-- Replaced the placeholder
          ),

          // Divider between the panes
          const VerticalDivider(width: 1, thickness: 1, color: Colors.black12),

          // ==========================================
          // RIGHT PANE (40%) - Customer, Cart & Checkout
          // ==========================================
          Expanded(
            flex: 4,
            child: const RightPaneWidget(), // <-- Replaced the placeholder
          ),
        ],
      ),
    );
  }
}
