import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../utils/globals.dart';

class PaymentImageScreen extends StatefulWidget {
  final int orderId;
  final String imageUrl;

  const PaymentImageScreen({
    Key? key,
    required this.orderId,
    required this.imageUrl,
  }) : super(key: key);

  @override
  State<PaymentImageScreen> createState() => _PaymentImageScreenState();
}

class _PaymentImageScreenState extends State<PaymentImageScreen> {
  @override
  void initState() {
    super.initState();
    NotificationEventHandler.onOrderDelivered = _handleOrderDelivered;
  }

  void _handleOrderDelivered(RemoteMessage message) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Your order has been delivered successfully!")),
    );

    // Delay navigation to allow Snackbar to show
    Future.delayed(const Duration(seconds: 2), () {
      // if (mounted) Navigator.of(context).pop();
      if (mounted) _navigateToSuccess(context);
    });
  }

  @override
  void dispose() {
    NotificationEventHandler.onOrderDelivered = null;
    super.dispose();
  }

  void _navigateToSuccess(BuildContext context) {
    context.goNamed(
      'orderSuccess',
      pathParameters: {'orderId': widget.orderId.toString()},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => _navigateToSuccess(context),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1,
              maxScale: 5,
              child: SizedBox.expand(
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Text('Failed to load payment image'));
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              label: const Text('Done'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: () => _navigateToSuccess(context),
            ),
          ),
        ],
      ),
    );
  }
}
