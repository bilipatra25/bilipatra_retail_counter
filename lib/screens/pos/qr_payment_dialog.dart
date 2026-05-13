import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'checkout_service.dart';

class QRPaymentDialog extends StatefulWidget {
  final int orderId;
  final double amount;
  final String qrImageUrl;
  final bool willPrint;
  final String? customerMobile;
  final VoidCallback? onPrint; // 🟢 NEW: Callback to trigger background printing

  const QRPaymentDialog({
    super.key,
    required this.orderId,
    required this.amount,
    required this.qrImageUrl,
    this.willPrint = true,
    this.customerMobile,
    this.onPrint, // 🟢 NEW
  });

  @override
  State<QRPaymentDialog> createState() => _QRPaymentDialogState();
}

class _QRPaymentDialogState extends State<QRPaymentDialog> {
  bool _isZoomed = true;
  bool _paymentReceived = false;
  bool _isSendingWhatsapp = false;
  StreamSubscription<DatabaseEvent>? _orderSubscription;

  late TextEditingController _whatsappController;

  @override
  void initState() {
    super.initState();
    _whatsappController = TextEditingController(text: widget.customerMobile ?? '');
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

            // 🟢 AUTO-PRINT TRIGGER: Fires immediately while dialog is still open
            if (widget.willPrint && widget.onPrint != null) {
              widget.onPrint!();
            }
          }
        }
      }
    });
  }

  Future<void> _sendWhatsappLink() async {
    final phone = _whatsappController.text.trim();

    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please enter a valid 10-digit number"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSendingWhatsapp = true);
    try {
      await CheckoutService.sendWhatsAppQR(
          context, widget.orderId, phone, widget.qrImageUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Payment Link sent via WhatsApp!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to send WhatsApp: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingWhatsapp = false);
    }
  }

  @override
  void dispose() {
    _whatsappController.dispose();
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      // 🟢 Returns 'paid_no_print' so the POS knows NOT to print again
                      onPressed: () => Navigator.pop(context, 'paid_no_print'),
                      icon: const Icon(Icons.close, color: Colors.black87),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        side: BorderSide(color: Colors.grey.shade400, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      label: const Text("Close", style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      // 🟢 Returns 'paid_print' so the POS knows to explicitly print
                      onPressed: () => Navigator.pop(context, 'paid_print'),
                      icon: const Icon(Icons.print, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      label: Text(
                        widget.willPrint ? "Print Again & Close" : "Print & Close",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: TextField(
                            controller: _whatsappController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(10),
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: "WhatsApp Number",
                              prefixIcon: const Icon(Icons.wechat, color: Colors.green),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSendingWhatsapp ? null : _sendWhatsappLink,
                          icon: _isSendingWhatsapp
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send, size: 18),
                          label: const Text("Send Link", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                          // 🟢 Returns 'paid_force' so the POS knows it was manually bypassed
                          onPressed: () => Navigator.pop(context, 'paid_force'),
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