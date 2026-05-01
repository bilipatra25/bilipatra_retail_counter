import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AdminDashboardModal extends StatefulWidget {
  const AdminDashboardModal({super.key});

  @override
  State<AdminDashboardModal> createState() => _AdminDashboardModalState();
}

class _AdminDashboardModalState extends State<AdminDashboardModal> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // Initialize the WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://retail-counter.bilipatra.com/login?username=9974882009&password=vraj@123'));
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 THE FIX: Set insetPadding to zero to remove default dialog margins
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.white,
      child: SizedBox(
        // 🟢 THE FIX: Force it to take up 100% of the screen width and height
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: SafeArea(
          child: Column(
            children: [
              // ==========================================
              // CUSTOM HEADER WITH BIG CLOSE BUTTON
              // ==========================================
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade900,
                  // Removed the rounded corners since it is now flush with the screen edges
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                        SizedBox(width: 12),
                        Text(
                          "Admin Dashboard",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),

                    // The "Get back to POS ASAP" Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      label: const Text("CLOSE & RETURN TO POS", style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),

              // ==========================================
              // THE ACTUAL DASHBOARD WEBVIEW
              // ==========================================
              Expanded(
                child: Stack(
                  children: [
                    WebViewWidget(controller: _controller),

                    // Show a loading spinner while React boots up
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.blueGrey),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}