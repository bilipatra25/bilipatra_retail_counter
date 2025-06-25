import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'TestPrint.dart';

class PrintScreen extends StatefulWidget {
  final dynamic user;
  final List<dynamic> products;

  const PrintScreen({super.key, required this.user, required this.products});

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a printer.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (!(await bluetooth.isConnected ?? false)) {
        await bluetooth.connect(_selectedDevice!);
      }

      await _saveSelectedDevice(_selectedDevice!);

      final printer = TestPrint();
      await printer.printInvoice(widget.user, widget.products);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✅ Printing started.")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Print failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thermal Printer"), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Top scrollable section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Select Bluetooth Printer",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
                  ],
                ),
              ),

              // Bottom fixed buttons
              const SizedBox(height: 10),
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
                      onPressed: () async {
                        final confirm = await _showExitConfirmation(context);
                        if (confirm == true) {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        }
                      },
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text("Exit"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16),
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
      ),
    );
  }

  Future<bool?> _showExitConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Confirm Exit"),
            content: const Text("Are you sure you want to exit to Home?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Yes"),
              ),
            ],
          ),
    );
  }
}
