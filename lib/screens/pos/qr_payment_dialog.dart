import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class QRPaymentDialog extends StatefulWidget {
  final int orderId;
  final double amount;
  final String qrImageUrl;
  final bool willPrint;

  const QRPaymentDialog({
    super.key,
    required this.orderId,
    required this.amount,
    required this.qrImageUrl,
    this.willPrint = true,
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

            // ==========================================
            // 🟢 DYNAMIC ACTION BUTTONS
            // ==========================================
            if (_paymentReceived)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, 'paid'),
                  icon: Icon(
                      widget.willPrint ? Icons.print : Icons.check_circle_outline,
                      color: Colors.white
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: Text(
                    widget.willPrint ? "Complete & Print Receipt" : "Complete Transaction",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context, 'close'),
                          icon: const Icon(Icons.arrow_back, color: Colors.black87),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            side: BorderSide(color: Colors.grey.shade400, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          label: const Text("Back to Cart", style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context, 'paid'),
                          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          label: const Text("Force Verify", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, 'cancel_order'),
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text("Cancel Order Entirely", style: TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}