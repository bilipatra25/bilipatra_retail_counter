import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:file_picker/file_picker.dart';

class AdminDashboardModal extends StatefulWidget {
  final String url;
  final String title;

  const AdminDashboardModal({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<AdminDashboardModal> createState() => _AdminDashboardModalState();
}

class _AdminDashboardModalState extends State<AdminDashboardModal> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final userJson = prefs.getString('user_json') ?? '{}';
    
    // Base64 encode the userJson to safely pass it in the URL
    final base64User = base64Encode(utf8.encode(userJson));
    
    // Append the JWT token and base64 user as query parameters
    final encodedToken = Uri.encodeComponent(token);
    final encodedUser = Uri.encodeComponent(base64User);
    
    final urlWithToken = widget.url.contains('?') 
        ? '${widget.url}&token=$encodedToken&user=$encodedUser' 
        : '${widget.url}?token=$encodedToken&user=$encodedUser';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
      );

    // 🟢 Handle Android File Chooser
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setOnShowFileSelector((FileSelectorParams params) async {
        final result = await FilePicker.pickFiles(
          allowMultiple: params.mode == FileSelectorMode.openMultiple,
          type: FileType.any,
        );
        if (result != null && result.files.isNotEmpty) {
          // WebView on Android expects proper file:// or content:// URIs,
          // so we map the raw absolute paths to file:// URIs.
          return result.paths
              .whereType<String>()
              .map((path) => Uri.file(path).toString())
              .toList();
        }
        return [];
      });
    }

    _controller = controller..loadRequest(Uri.parse(urlWithToken));

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.white,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(color: Colors.blueGrey.shade900),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        // 🟢 Use the dynamic Title
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      label: const Text(
                        "CLOSE & RETURN TO POS",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(
                          color: Colors.blueGrey,
                        ),
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
