import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class InvoiceWebViewScreen extends StatefulWidget {
  final String? url;

  const InvoiceWebViewScreen({
    super.key,
    this.url =
    "https://b12greenfood.shop:3003/storelocate/invoice/internal-invoice-preview?order_id=224",
  });

  @override
  State<InvoiceWebViewScreen> createState() => _InvoiceWebViewScreenState();
}

class _InvoiceWebViewScreenState extends State<InvoiceWebViewScreen> {
  late final WebViewController controller;
  bool _isLoading = true; // <-- loader flag

  @override
  void initState() {
    super.initState();

    final WebViewController ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..loadRequest(Uri.parse(widget.url ?? ""));

    // Android-specific zoom fix
    if (ctrl.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (ctrl.platform as AndroidWebViewController).setUseWideViewPort(true);
    }

    controller = ctrl;

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          setState(() {
            _isLoading = true; // show loader
          });
        },
        onPageFinished: (url) {
          // Run JS for zoom/viewport
          controller.runJavaScript("""
            var meta = document.querySelector('meta[name=viewport]');
            if (!meta) {
              meta = document.createElement('meta');
              meta.name = "viewport";
              meta.content = "width=device-width, initial-scale=0.9, maximum-scale=1.0, user-scalable=yes";
              document.head.appendChild(meta);
            } else {
              meta.setAttribute("content", "width=device-width, initial-scale=0.9, maximum-scale=1.0, user-scalable=yes");
            }
            document.body.style.zoom = "0.8";
          """);

          setState(() {
            _isLoading = false; // hide loader
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
