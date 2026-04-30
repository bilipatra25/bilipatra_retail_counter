import 'package:flutter/foundation.dart';

class PrinterService {
  static Future<void> printReceipt({
    required int orderId,
    required double totalAmount,
  }) async {
    debugPrint("🖨️ --- START PRINT JOB ---");
    debugPrint("Order ID: $orderId");
    debugPrint("Total: ₹$totalAmount");
    debugPrint("🖨️ --- END PRINT JOB ---");

    // TODO: In Phase 1, insert blue_thermal_printer code here
    // TODO: In Phase 2, delete Bluetooth code and insert sunmi_printer_plus code here
  }
}