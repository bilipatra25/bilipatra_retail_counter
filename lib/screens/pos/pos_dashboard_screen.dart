import 'package:bilipatra_retail_counter/screens/pos/recent_bills_modal.dart';
import 'package:bilipatra_retail_counter/screens/pos/right_pane_widget.dart';
import 'package:flutter/material.dart';
// Inside pos_dashboard_screen.dart
import 'left_pane_widget.dart'; // Import it

class PosDashboardScreen extends StatelessWidget {
  const PosDashboardScreen({super.key});

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
          // Future: Wholesale Inquiry Button
          TextButton.icon(
            onPressed: () {
              // Open wholesale inquiry bottom sheet
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
