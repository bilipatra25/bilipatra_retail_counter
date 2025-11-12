import 'package:bilipatra_retail_counter/utils/globals.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'TestPrint.dart';
import 'models/order_model.dart';

class PrintScreen extends StatefulWidget {
  final OrderModelResponse order;

  const PrintScreen({super.key, required this.order});

  @override
  State<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends State<PrintScreen> {
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  final String _lastDeviceKey = "last_selected_printer";

  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  // Load bonded devices and match previously selected device if available
  Future<void> _initBluetooth() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Searching for devices...';
    });

    try {
      if (await bluetooth.isOn ?? false) {
        final devices = await bluetooth.getBondedDevices();
        SharedPreferences prefs = await SharedPreferences.getInstance();
        final lastAddress = prefs.getString(_lastDeviceKey);

        BluetoothDevice? matchedDevice;
        try {
          matchedDevice = devices.firstWhere((d) => d.address == lastAddress);
        } catch (_) {
          matchedDevice = null;
        }

        setState(() {
          _devices = devices;
          _selectedDevice = matchedDevice;
          _statusMessage =
              devices.isNotEmpty
                  ? 'Select a device to print'
                  : 'No paired Bluetooth printers found.';
        });
      } else {
        setState(() {
          _statusMessage = 'Bluetooth is off. Please enable it.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error fetching devices: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Save selected printer to SharedPreferences
  Future<void> _saveSelectedDevice(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDeviceKey, device.address!);
  }

  // Connect and print invoice
  Future<void> _connectAndPrint() async {
    if (_selectedDevice == null) {
      showAppSnackBar(context, "Please select a printer.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (!(await bluetooth.isConnected ?? false)) {
        await bluetooth.connect(_selectedDevice!);
      }

      await _saveSelectedDevice(_selectedDevice!);

      final printer = TestPrint();
      await printer.printInvoice(widget.order);
      showAppSnackBar(context, "✅ Printing started.");
    } catch (e) {
      print(e);
      showAppSnackBar(context, "❌ Print failed: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // important for bottom sheet
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            Row(
              children: [
                const Text(
                  "Select Bluetooth Printer",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (_) => AlertDialog(
                            title: const Text("How to Connect Printer"),
                            content: const Text(
                              "1. Power on your EZO Bluetooth printer.\n"
                              "2. Open your phone's Bluetooth settings.\n"
                              "3. Pair with the printer (name starts with 'EZO' or similar).\n"
                              "4. Come back and select the printer from the dropdown.\n\n"
                              "Once paired, it will be auto-selected next time.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Got it"),
                              ),
                            ],
                          ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),
            _devices.isEmpty
                ? Text(_statusMessage)
                : DropdownButton<BluetoothDevice>(
                  isExpanded: true,
                  value: _selectedDevice,
                  hint: const Text("Select a printer"),
                  items:
                      _devices.map((device) {
                        return DropdownMenuItem(
                          value: device,
                          child: Text(device.name ?? "Unnamed Device"),
                        );
                      }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDevice = val;
                    });
                    if (val != null) _saveSelectedDevice(val);
                  },
                ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _connectAndPrint,
                    icon: const Icon(Icons.print),
                    label: const Text("Print Now"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      ); // This closes the current screen or bottom sheet
                    },
                    icon: const Icon(Icons.close),
                    label: const Text("Close"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
