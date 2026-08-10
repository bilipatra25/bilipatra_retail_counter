import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user.dart';
import '../../services/api_service.dart';
import 'qr_payment_dialog.dart';

class CustomerDuesDialog extends StatefulWidget {
  final UserModel customer;

  const CustomerDuesDialog({super.key, required this.customer});

  @override
  State<CustomerDuesDialog> createState() => _CustomerDuesDialogState();
}

class _CustomerDuesDialogState extends State<CustomerDuesDialog> {
  bool _isLoading = true;
  List<dynamic> _pendingBills = [];

  @override
  void initState() {
    super.initState();
    _fetchBills();
  }

  Future<void> _fetchBills() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService(context).getCustomerPendingBills(widget.customer.id);
      if (res['flag'] == 1 || res['code'] == 200) {
        setState(() {
          _pendingBills = res['data'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching dues: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPaymentDialog(Map<String, dynamic> bill) {
    double balanceDue = double.tryParse(bill['balance_due'].toString()) ?? 0.0;
    double payAmount = balanceDue;
    String method = 'cash';
    final TextEditingController amountCtrl = TextEditingController(text: balanceDue.toStringAsFixed(0));
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
            builder: (context, setModalState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text("Settle Pending Bill"),
                content: SizedBox(
                  width: 350,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Order #${bill['order_id']}  •  Total Bill: ₹${bill['total_amount']}", style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Balance Due:", style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                            Text("₹${balanceDue.toStringAsFixed(2)}", style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text("Paying Amount (₹)", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        onChanged: (val) {
                          setModalState(() {
                            payAmount = double.tryParse(val) ?? 0.0;
                            if (payAmount > balanceDue) {
                              payAmount = balanceDue;
                              amountCtrl.text = balanceDue.toStringAsFixed(2);
                            }
                          });
                        },
                        decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee)),
                      ),
                      const SizedBox(height: 16),
                      const Text("Payment Method", style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Expanded(child: RadioListTile<String>(title: const Text("Cash"), value: "cash", groupValue: method, onChanged: (val) => setModalState(() => method = val!))),
                          Expanded(child: RadioListTile<String>(title: const Text("UPI"), value: "online", groupValue: method, onChanged: (val) => setModalState(() => method = val!))),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: const Text("Cancel")),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                    onPressed: isProcessing ? null : () async {
                      if (payAmount <= 0) return;
                      setModalState(() => isProcessing = true);
                      try {
                        final response = await ApiService(context).payPendingBill(
                          orderId: bill['order_id'],
                          customerId: widget.customer.id,
                          amount: payAmount,
                          paymentMethod: method,
                        );

                        Navigator.pop(ctx); // Close payment modal

                        if (method == 'online') {
                          // 🟢 OPEN QR DIALOG FOR UPI REPAYMENT
                          final qrImageUrl = response['data']['image_url'];
                          final result = await showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => QRPaymentDialog(
                              orderId: bill['order_id'],
                              amount: payAmount,
                              qrImageUrl: qrImageUrl,
                              willPrint: false, // Repayments usually don't need immediate POS print, but you can change to true
                              customerMobile: widget.customer.number,
                            ),
                          );

                          if (result == 'paid_no_print' || result == 'paid_print' || result == 'paid_force' || result == 'paid' || result == true) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ UPI Repayment Successful!"), backgroundColor: Colors.green));
                          }
                        } else {
                          // CASH SUCCESS
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Cash Repayment Successful!"), backgroundColor: Colors.green));
                        }

                        _fetchBills(); // Refresh the list!

                      } catch (e) {
                        setModalState(() => isProcessing = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Failed: $e"), backgroundColor: Colors.red));
                      }
                    },
                    child: isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Receive Payment"),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text("${widget.customer.name}'s Khata", style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _pendingBills.isEmpty
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, color: Colors.green.shade200, size: 60),
              const SizedBox(height: 16),
              const Text("No pending dues! All clear.", style: TextStyle(fontSize: 18, color: Colors.grey)),
            ],
          ),
        )
            : ListView.builder(
          itemCount: _pendingBills.length,
          itemBuilder: (ctx, i) {
            final bill = _pendingBills[i];
            final date = DateTime.tryParse(bill['created_at'].toString());
            final formattedDate = date != null ? "${date.day}/${date.month}/${date.year}" : "N/A";

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade100)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: Icon(Icons.receipt_long, color: Colors.red.shade400),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Order #${bill['order_id']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("Date: $formattedDate", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text("Total: ₹${bill['total_amount']}  |  Paid: ₹${bill['paid_amount']}", style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Due: ₹${bill['balance_due']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red.shade700)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: () => _showPaymentDialog(bill),
                          child: const Text("Pay Dues"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}