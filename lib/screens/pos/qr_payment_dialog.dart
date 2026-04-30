import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'checkout_service.dart';

class QRPaymentDialog extends StatefulWidget {
  final int orderId;
  final double amount;
  final String qrImageUrl;
  final String? initialMobile;

  const QRPaymentDialog({
    super.key,
    required this.orderId,
    required this.amount,
    required this.qrImageUrl,
    this.initialMobile,
  });

  @override
  State<QRPaymentDialog> createState() => _QRPaymentDialogState();
}

class _QRPaymentDialogState extends State<QRPaymentDialog> {
  bool _isSendingWhatsApp = false;
  bool _isWhatsAppSent = false;

  bool _isZoomed = true;

  void _showWhatsAppPrompt() {
    final TextEditingController mobileController = TextEditingController(
      text: widget.initialMobile ?? "",
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Send QR via WhatsApp"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Confirm or edit the customer's mobile number:",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                autofocus: true,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.phone, color: Colors.green),
                  prefixText: "+91 ",
                  border: OutlineInputBorder(),
                  labelText: "Mobile Number",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (mobileController.text.length != 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Enter a valid 10-digit number"),
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                _sendToAiSensy(mobileController.text);
              },
              child: const Text("Send Message"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendToAiSensy(String mobile) async {
    setState(() => _isSendingWhatsApp = true);
    try {
      final success = await CheckoutService.sendWhatsAppQR(
        context,
        widget.orderId,
        mobile,
        widget.qrImageUrl,
      );
      if (success) {
        setState(() => _isWhatsAppSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ WhatsApp sent!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Failed: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSendingWhatsApp = false);
    }
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
            const Text(
              "Scan to Pay",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
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
                    height:
                        400, // 🟢 THE FIX: Hard constraint prevents the "flat line" collapse instantly
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () => setState(() => _isZoomed = !_isZoomed),
                        child: Image.network(
                          widget.qrImageUrl,
                          fit: _isZoomed ? BoxFit.fitWidth : BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            // The Center widget will now automatically expand to fill the 400px height
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.blueAccent,
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Fetching Secure QR...",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          },
                          errorBuilder:
                              (context, error, stackTrace) => const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isZoomed ? Icons.zoom_out_map : Icons.zoom_in,
                          color: Colors.white,
                        ),
                        onPressed: () => setState(() => _isZoomed = !_isZoomed),
                        tooltip: "Toggle Banner",
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _isSendingWhatsApp || _isWhatsAppSent
                        ? null
                        : _showWhatsAppPrompt,
                icon:
                    _isSendingWhatsApp
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Icon(
                          _isWhatsAppSent ? Icons.check_circle : Icons.chat,
                          color:
                              _isWhatsAppSent
                                  ? Colors.green
                                  : Colors.green.shade600,
                        ),
                label: Text(
                  _isSendingWhatsApp
                      ? "Sending..."
                      : _isWhatsAppSent
                      ? "Sent to WhatsApp"
                      : "Send QR via WhatsApp",
                  style: TextStyle(
                    color:
                        _isWhatsAppSent ? Colors.green : Colors.green.shade700,
                    fontSize: 18,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.green.shade600, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Verify Payment & Close",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
