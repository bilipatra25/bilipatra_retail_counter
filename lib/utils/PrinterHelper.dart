// printer_helper.dart
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../TestPrint.dart';
import '../models/order_model.dart';

class PrinterHelper {
  static const String _lastDeviceKey = "last_selected_printer";
  static final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  /// Print invoice directly using last saved printer
  static Future<bool> printInvoice(OrderModelResponse order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString(_lastDeviceKey);

      if (address == null) {
        throw Exception("No default printer configured.");
      }

      final devices = await bluetooth.getBondedDevices();
      final device = devices.firstWhere((d) => d.address == address);

      if (!(await bluetooth.isConnected ?? false)) {
        await bluetooth.connect(device);
      }

      final printer = TestPrint();
      await printer.printInvoice(order);

      return true;
    } catch (e) {
      print("⚠️ Print failed: $e");
      return false;
    }
  }

  /// Save selected printer
  static Future<void> saveDefaultPrinter(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDeviceKey, device.address!);
  }

  /// Fetch bonded printers
  static Future<List<BluetoothDevice>> getBondedDevices() async {
    return await bluetooth.getBondedDevices();
  }
}
