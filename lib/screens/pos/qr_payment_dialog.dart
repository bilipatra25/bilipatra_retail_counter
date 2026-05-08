import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class QRPaymentDialog extends StatefulWidget {
  final int orderId;
  final double amount;
  final String qrImageUrl;

  const QRPaymentDialog({
    super.key,
    required this.orderId,
    required this.amount,
    required this.qrImageUrl,
  });

  @override
  State<QRPaymentDialog> createState() => _QRPaymentDialogState();
}

class _QRPaymentDialogState extends State<QRPaymentDialog> {
  bool _isZoomed = true;
  bool _paymentReceived = false;
  StreamSubscription<DatabaseEvent>? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _listenForPayment();
  }

  // 🟢 NEW: Auto-Listen to Firebase, instantly update UI without auto-closing
  void _listenForPayment() {
    _orderSubscription = FirebaseDatabase.instance
        .ref('retail/orders/${widget.orderId}')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        if (data['paid'] == true && !_paymentReceived) {
          if (mounted) {
            setState(() => _paymentReceived = true);
            // No Future.delayed here! The cashier will manually close it.
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _paymentReceived ? "Payment Received!" : "Scan to Pay",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _paymentReceived ? Colors.green.shade700 : Colors.black87
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Order #${widget.orderId}  •  ₹${widget.amount.toStringAsFixed(0)}",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            Flexible(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 400,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                          color: _paymentReceived ? Colors.green.shade400 : Colors.grey.shade300,
                          width: 2
                      ),
                      borderRadius: BorderRadius.circular(16),
                      // Add a soft glow when payment succeeds
                      boxShadow: _paymentReceived
                          ? [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)]
                          : [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _paymentReceived
                          ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified, color: Colors.green, size: 120),
                          const SizedBox(height: 24),
                          Text(
                              "Transaction Successful",
                              style: TextStyle(fontSize: 26, color: Colors.green.shade800, fontWeight: FontWeight.bold)
                          ),
                        ],
                      )
                          : GestureDetector(
                        onTap: () => setState(() => _isZoomed = !_isZoomed),
                        child: Image.network(
                          widget.qrImageUrl,
                          fit: _isZoomed ? BoxFit.fitWidth : BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.blueAccent,
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text("Fetching Secure QR...", style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!_paymentReceived)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(_isZoomed ? Icons.zoom_out_map : Icons.zoom_in, color: Colors.white),
                          onPressed: () => setState(() => _isZoomed = !_isZoomed),
                          tooltip: "Toggle Zoom",
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // 🟢 Button is always active so they can manually close it
                onPressed: () => Navigator.pop(context, true),
                icon: Icon(
                    _paymentReceived ? Icons.print : Icons.check_circle_outline,
                    color: Colors.white
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _paymentReceived ? Colors.green.shade700 : Colors.blueAccent.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                label: Text(
                  _paymentReceived ? "Complete & Print Receipt" : "Verify Payment & Close",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}