import 'dart:async';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/order_model.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../utils/PrinterHelper.dart';
import '../../utils/globals.dart';

class PaymentQRPage extends StatefulWidget {
  const PaymentQRPage({super.key});

  @override
  State<PaymentQRPage> createState() => _PaymentQRPageState();
}

class _PaymentQRPageState extends State<PaymentQRPage> {
  // 🟢 Connects to your real-time Firebase Orders node
  final DatabaseReference _ordersRef = FirebaseDatabase.instance.refFromURL(
    'https://storelocator-fe8e7-default-rtdb.asia-southeast1.firebasedatabase.app/retail/orders',
  );

  List<Map<String, dynamic>> _orderList = [];
  Map<String, dynamic>? _currentOrder;

  bool isLoading = true;
  bool isExpired = false;
  bool isPaid = false;
  bool isOrderLoading = false;

  Timer? countdownTimer;
  Duration remainingTime = const Duration(hours: 2);
  OrderModelResponse? order;

  StreamSubscription<DatabaseEvent>? _addedSub;
  StreamSubscription<DatabaseEvent>? _changedSub;
  bool _autoPrintEnabled = true;

  final Set<String> _recentlyPrinted = {};
  late DateTime _sessionStartTime;
  bool _showPlaceholder = false;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now().toUtc();
    _loadAutoPrintSetting();
    NotificationEventHandler.onOrderDelivered = _handleOrderDelivered;
    _listenToOrders();

    // 💤 Prevent the customer-facing tablet screen from ever sleeping
    WakelockPlus.enable();
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    _addedSub?.cancel();
    _changedSub?.cancel();
    NotificationEventHandler.onOrderDelivered = null;
    countdownTimer?.cancel();
    _inactivityTimer?.cancel();

    // 💤 Allow screen to sleep again when leaving this page
    WakelockPlus.disable();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    // Show screensaver after 2 minutes of no new orders/taps
    _inactivityTimer = Timer(const Duration(minutes: 2), () {
      if (mounted) setState(() => _showPlaceholder = true);
    });
  }

  Future<void> _loadAutoPrintSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoPrintEnabled = prefs.getBool("auto_print_enabled") ?? true;
    });
  }

  Future<void> _saveAutoPrintSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("auto_print_enabled", value);
  }

  // 🟢 NEW: Auto-Listen to Firebase, instantly update UI without auto-closing
  void _listenToOrders() {
    debugPrint("👂 Listening to Firebase orders...");

    // 🟢 UPDATED: Fetch the 5 most recent orders to ensure we don't miss simultaneous checkouts
    _addedSub = _ordersRef.orderByChild('createdAt').limitToLast(5).onChildAdded.listen((event) {
      if (mounted) _updateOrderData(event.snapshot, isNew: true);
    });

    _changedSub = _ordersRef.onChildChanged.listen((event) {
      if (mounted) {
        // 🟢 PREVENT SPAM: Only process changes if it matches our CURRENT order,
        // or if it's a completely new active order taking priority.
        final rawData = event.snapshot.value;
        if (rawData is Map) {
          final changedOrderId = rawData['orderId']?.toString();

          if (_currentOrder == null || _currentOrder?['orderId'].toString() == changedOrderId) {
            _updateOrderData(event.snapshot);
          }
        }
      }
    });

    // Failsafe: Stop initial full-page loader after timeout
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && isLoading) setState(() => isLoading = false);
    });
  }

  void _updateOrderData(DataSnapshot snapshot, {bool isNew = false}) async {
    setState(() => _showPlaceholder = false);
    _resetInactivityTimer();

    final rawData = snapshot.value;
    if (rawData == null || rawData is! Map) return;

    final data = Map<String, dynamic>.from(rawData);
    final orderId = data['orderId']?.toString();
    if (orderId == null) return;

    bool shouldAutoPrint = false;

    final existingIndex = _orderList.indexWhere(
      (o) => o['orderId'].toString() == orderId,
    );

    if (existingIndex >= 0) {
      final prevOrder = _orderList[existingIndex];
      final prevPaid = prevOrder['paid'] == true;
      final newPaid = data['paid'] == true;

      // ✅ Trigger print when webhook fires (unpaid -> paid online)
      if (!prevPaid && newPaid && data['method'] == "online") {
        shouldAutoPrint = true;
      }

      _orderList[existingIndex] = data;
    } else {
      _orderList.add(data);

      // ✅ Trigger print instantly for brand new cash orders
      if (data['method'] == "cash" && data['printed'] != true) {
        shouldAutoPrint = true;
      }
    }

    // ✅ Keep only the last 10 most recent orders in memory
    if (_orderList.length > 10) {
      _orderList = _orderList.sublist(_orderList.length - 10);
    }

    // Update screen if this is a new order OR the order currently being displayed
    if (_currentOrder == null ||
        _currentOrder?['orderId'].toString() == orderId ||
        isNew) {
      _setCurrentOrder(data, shouldAutoPrint: shouldAutoPrint);
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _setCurrentOrder(
    Map<String, dynamic> data, {
    bool shouldAutoPrint = false,
  }) async {
    final newOrderId = data['orderId'].toString();

    // 🟢 PREVENT SPAM: If we already have this specific order fully loaded,
    // just update the UI state (paid/expired) and skip the heavy HTTP API call!
    final bool needsApiFetch = order == null || order!.orderId != newOrderId;

    setState(() {
      _currentOrder = data;
      isPaid = data['paid'] == true;
      isExpired = false;
      if (needsApiFetch) isOrderLoading = true;
    });

    if (data['createdAt'] != null) {
      try {
        final utc = DateFormat(
          "yyyy-MM-dd HH:mm:ss",
        ).parseUtc(data['createdAt']);
        _startCountdownTimer(utc);
      } catch (e) {
        debugPrint("Invalid date format: $e");
      }
    }

    try {
      OrderModelResponse? loadedOrder = order;

      // 🟢 Only hit the API if we don't already have the receipt data for this ID
      if (needsApiFetch) {
        debugPrint("🌐 Fetching full receipt data for Order #$newOrderId");
        loadedOrder = await _loadOrderDetails(newOrderId);

        if (mounted) {
          setState(() {
            order = loadedOrder;
            isOrderLoading = false;
          });
        }
      }

      if (_autoPrintEnabled && shouldAutoPrint && loadedOrder != null) {
        await _handleAutoPrint(data, loadedOrder);
      }
    } catch (e) {
      debugPrint("❌ Error during order fetch: $e");
      if (mounted) {
        setState(() => isOrderLoading = false);
        showAppSnackBar(context, "❌ Error fetching order details: $e");
      }
    }
  }

  void _startCountdownTimer(DateTime createdAtUtc) {
    countdownTimer?.cancel();
    if (isPaid) return;

    final expiryTime = createdAtUtc.add(const Duration(hours: 2));

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now().toUtc();
      if (now.isAfter(expiryTime)) {
        setState(() {
          isExpired = true;
          remainingTime = Duration.zero;
        });
        timer.cancel();
      } else {
        setState(() {
          remainingTime = expiryTime.difference(now);
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    final data = _currentOrder;
    final title =
        isPaid
            ? "Payment Completed"
            : isExpired
            ? "QR Expired"
            : "Complete Payment";

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar:
          _showPlaceholder
              ? null
              : AppBar(
                backgroundColor:
                    isPaid
                        ? Colors.green.shade700
                        : isExpired
                        ? Colors.grey.shade700
                        : Colors.blueAccent.shade700,
                foregroundColor: Colors.white,
                elevation: 2,
                title: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_orderList.isEmpty) return;
                          _showRecentOrdersDialog();
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "#${data?['orderId'] ?? '...'} - ${data?['name'] ?? 'Waiting for order'}",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_drop_down_circle,
                              color: Colors.white70,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (data != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "₹${double.tryParse(data['amount']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, size: 28),
                  onPressed: () => context.pop(),
                ),
              ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _resetInactivityTimer,
        onPanDown: (_) => _resetInactivityTimer(),
        child: Stack(
          children: [
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              )
            else if (data == null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Waiting for next order...",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(child: _buildQrView(data)),

            // 🖼️ Tablet Screensaver Overlay
            if (_showPlaceholder)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _showPlaceholder = false);
                    _resetInactivityTimer();
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/placeholder_2.jpg', // Make sure this exists!
                        fit: BoxFit.cover,
                      ),
                      Container(color: Colors.black.withOpacity(0.3)),
                      Positioned(
                        bottom: 60,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app,
                                  size: 28,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "Tap screen to wake",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton:
          _showPlaceholder
              ? null
              : FloatingActionButton.extended(
                backgroundColor: Colors.black87,
                icon: const Icon(Icons.print, color: Colors.white),
                label: const Text(
                  "Printer Settings",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: _showPrinterSettings,
              ),
    );
  }

  // 🟢 TABLET OPTIMIZED QR VIEW
  Widget _buildQrView(Map<String, dynamic> data) {
    final qrImageUrl = data['image']?.toString();
    final isCashOrder = data['method']?.toString().toLowerCase() == 'cash';

    if (isCashOrder) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500, // Constrained for tablet
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, color: Colors.green, size: 100),
              const SizedBox(height: 20),
              const Text(
                "Cash Payment",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Order ID: #${data['orderId']}",
                style: const TextStyle(fontSize: 20, color: Colors.black87),
              ),
              const SizedBox(height: 30),
              if (isPaid)
                _orderActionButtons()
              else
                const Text(
                  "Please collect cash at the counter.",
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      );
    }

    // Online QR Layout
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 450, // Constrained width so QR isn't massive on tablets
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // QR Code Image
            Container(
              height: 350,
              width: 350,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ColorFiltered(
                  colorFilter:
                      isPaid
                          ? const ColorFilter.mode(
                            Colors.white70,
                            BlendMode.lighten,
                          )
                          : const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.multiply,
                          ),
                  child: CachedNetworkImage(
                    imageUrl: qrImageUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey.shade200,
                          highlightColor: Colors.white,
                          child: Container(color: Colors.white),
                        ),
                    errorWidget:
                        (context, url, error) => const Center(
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

            const SizedBox(height: 24),

            // Status Area
            if (!isPaid && !isExpired)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Expires in: ${_formatDuration(remainingTime)}",
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else if (isPaid)
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green, size: 36),
                      SizedBox(width: 10),
                      Text(
                        "Payment Successful!",
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _orderActionButtons(),
                ],
              )
            else if (isExpired)
              const Text(
                "QR Code Expired",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _orderActionButtons() {
    if (isOrderLoading)
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              if (order == null) return;
              await PrinterHelper.printInvoice(order!);
            },
            icon: const Icon(Icons.print),
            label: const Text("Reprint"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                () => _navigateToSuccess(context, _currentOrder?['orderId']),
            icon: const Icon(Icons.receipt_long),
            label: const Text("View Bill"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _showRecentOrdersDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Recent Live Orders"),
          content: SizedBox(
            width: 400,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _orderList.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                // Reverse the list to show newest on top
                final order = _orderList[_orderList.length - 1 - index];
                final id = order['orderId'];
                final name = order['name'] ?? '';
                final paid = order['paid'] == true;

                return ListTile(
                  leading: Icon(
                    order['method'] == 'cash' ? Icons.payments : Icons.qr_code,
                    color: Colors.blueGrey,
                  ),
                  title: Text(
                    "#$id - $name",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing:
                      paid
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(
                            Icons.pending_actions,
                            color: Colors.orange,
                          ),
                  onTap: () {
                    _setCurrentOrder(order);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // 🟢 Printer Settings Bottom Sheet
  void _showPrinterSettings() async {
    final devices = await PrinterHelper.getBondedDevices();
    final prefs = await SharedPreferences.getInstance();
    final lastAddress = prefs.getString("last_selected_printer");

    if (devices.isEmpty && mounted) {
      showAppSnackBar(context, "No paired Bluetooth printers found.");
      return;
    }

    BluetoothDevice? defaultDevice;
    try {
      defaultDevice = devices.firstWhere((d) => d.address == lastAddress);
    } catch (_) {}

    if (mounted) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) {
          BluetoothDevice? selected = defaultDevice;
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Printer Configuration",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    DropdownButtonFormField<BluetoothDevice>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Select Hardware Printer",
                      ),
                      isExpanded: true,
                      value: selected,
                      items:
                          devices
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d.name ?? "Unnamed Device"),
                                ),
                              )
                              .toList(),
                      onChanged: (val) => setSheetState(() => selected = val),
                    ),
                    const SizedBox(height: 16),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Auto-Print Receipts",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        "Print automatically when a customer pays online",
                      ),
                      value: _autoPrintEnabled,
                      activeColor: Colors.green,
                      onChanged: (val) async {
                        setSheetState(() => _autoPrintEnabled = val);
                        await _saveAutoPrintSetting(val);
                      },
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            selected == null
                                ? null
                                : () async {
                                  await PrinterHelper.saveDefaultPrinter(
                                    selected!,
                                  );
                                  if (mounted) {
                                    Navigator.pop(context);
                                    showAppSnackBar(
                                      context,
                                      "✅ ${selected!.name} saved as default printer",
                                      success: true,
                                    );
                                  }
                                },
                        icon: const Icon(Icons.save),
                        label: const Text("Save Preferences"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  // --- Helpers ---
  Future<OrderModelResponse?> _loadOrderDetails(String orderId) async {
    try {
      final res = await ApiService(context).orderListById(orderId);
      if (res['flag'] == 1 && res['data'] != null) {
        OrderModelResponse order = OrderModelResponse.fromJson(res['data']);
        order.orderId = orderId;
        return order;
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error loading order: $e");
      return null;
    }
  }

  void _handleOrderDelivered(RemoteMessage message) {
    showAppSnackBar(context, "Your order has been delivered successfully!");
  }

  void _navigateToSuccess(BuildContext context, dynamic data) {
    Provider.of<AppProvider>(
      context,
      listen: false,
    ).clearCartAndCustomer(); // Updated to match your new AppProvider method
    context.pushNamed(
      'orderSuccess',
      pathParameters: {'orderId': data.toString()},
    );
  }

  Future<void> _handleAutoPrint(
    Map<String, dynamic> data,
    OrderModelResponse loadedOrder,
  ) async {
    final orderId = data['orderId'].toString();

    if (_recentlyPrinted.contains(orderId)) return;

    try {
      final createdAt = DateFormat(
        "yyyy-MM-dd HH:mm:ss",
      ).parseUtc(data['createdAt']);
      if (createdAt.isBefore(
        _sessionStartTime.subtract(const Duration(seconds: 5)),
      ))
        return;
    } catch (_) {}

    final latestSnapshot = await _ordersRef.child(orderId).get();
    final latestData = latestSnapshot.value as Map?;
    if (latestData?['printed'] == true) return;

    final success = await PrinterHelper.printInvoice(loadedOrder);
    if (success) {
      _recentlyPrinted.add(orderId);
      await _ordersRef.child(orderId).update({'printed': true});
    }

    if (mounted) {
      showAppSnackBar(
        context,
        success ? "✅ Invoice printed" : "⚠️ Print failed. Check printer.",
        success: success,
      );
    }
  }
}
