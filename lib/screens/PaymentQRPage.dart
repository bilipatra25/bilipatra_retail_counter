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

import '../PrintScreen.dart';
import '../models/order_model.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../utils/PrinterHelper.dart';
import '../utils/globals.dart';

class PaymentQRPage extends StatefulWidget {
  const PaymentQRPage({Key? key}) : super(key: key);

  @override
  State<PaymentQRPage> createState() => _PaymentQRPageState();
}

class _PaymentQRPageState extends State<PaymentQRPage> {
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

    // 💤 Prevent screen from sleeping
    WakelockPlus.enable();

    // Start inactivity timer
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    _addedSub?.cancel();
    _changedSub?.cancel();
    NotificationEventHandler.onOrderDelivered = null;

    // 💤 Allow screen to sleep again
    WakelockPlus.disable();

    // Cancel inactivity timer
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 1), () {
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

  void _listenToOrders() {
    debugPrint("👂 Listening to Firebase orders...");

    _addedSub = _ordersRef.onChildAdded.listen((event) {
      if (mounted) _updateOrderData(event.snapshot, isNew: true);
    });

    _changedSub = _ordersRef.onChildChanged.listen((event) {
      if (mounted) _updateOrderData(event.snapshot);
    });

    // Stop loader after timeout
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

    // Check if order already exists
    final existingIndex = _orderList.indexWhere(
      (o) => o['orderId'].toString() == orderId,
    );

    if (existingIndex >= 0) {
      final prevOrder = _orderList[existingIndex];
      final prevPaid = prevOrder['paid'] == true;
      final newPaid = data['paid'] == true;

      // ✅ Trigger print only when online payment changes from unpaid → paid
      if (!prevPaid && newPaid && data['method'] == "online") {
        shouldAutoPrint = true;
      }

      _orderList[existingIndex] = data;
    } else {
      _orderList.add(data);

      // ✅ For new cash orders, print if not yet printed
      if (data['method'] == "cash" && data['printed'] != true) {
        shouldAutoPrint = true;
      }
    }

    // ✅ Keep only the last 5 most recent orders
    if (_orderList.length > 10) {
      _orderList = _orderList.sublist(_orderList.length - 5);
    }

    // ✅ Update current order only if it's new or currently active
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
    setState(() {
      _currentOrder = data;
      isPaid = data['paid'] == true;
      isExpired = false;
      isOrderLoading = true; // Start loader
    });

    // Handle countdown safely
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
      final loadedOrder = await _loadOrderDetails(data['orderId'].toString());
      if (loadedOrder == null) {
        debugPrint("⚠️ Failed to load order details");
      }

      if (mounted) {
        setState(() {
          order = loadedOrder;
          isOrderLoading = false; // Stop loader
        });
      }

      // Auto-print logic remains the same...
      if (_autoPrintEnabled && shouldAutoPrint && loadedOrder != null) {
        await _handleAutoPrint(data, loadedOrder);
      }
    } catch (e) {
      debugPrint("❌ Error during order fetch/print: $e");
      if (mounted) {
        setState(() => isOrderLoading = false);
        showAppSnackBar(context, "❌ Error: $e");
      }
    }
  }

  void _startCountdownTimer(DateTime createdAtUtc) {
    countdownTimer?.cancel();
    if (isPaid) return;

    final expiryTime = createdAtUtc.add(const Duration(hours: 2));
    final now = DateTime.now().toUtc();

    if (now.isAfter(expiryTime)) {
      setState(() => isExpired = true);
      return;
    }

    remainingTime = expiryTime.difference(now);
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
      appBar:
          _showPlaceholder
              ? null
              : AppBar(
                backgroundColor:
                    isPaid
                        ? Colors.green
                        : isExpired
                        ? Colors.grey
                        : Colors.blueAccent,
                foregroundColor: Colors.white,
                title: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_orderList.isEmpty) return;

                          showModalBottomSheet(
                            context: context,
                            builder: (context) {
                              return ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _orderList.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (context, index) {
                                  final order = _orderList[index];
                                  final id = order['orderId'];
                                  final name = order['name'] ?? '';
                                  final paid = order['paid'] == true;
                                  return ListTile(
                                    title: Text("#$id - $name"),
                                    trailing:
                                        paid
                                            ? const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                            )
                                            : null,
                                    onTap: () {
                                      _setCurrentOrder(order);
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "#${data?['orderId'] ?? ''} - ${data?['name'] ?? ''}",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (data != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "₹${(data['amount'] ?? 0).toString().replaceAll(RegExp(r'\.0+$'), '')}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
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
              const Center(child: CircularProgressIndicator())
            else if (data == null)
              const Center(child: Text("No payment QR available yet."))
            else
              _buildQrView(data),

            // 🖼️ Placeholder overlay after inactivity
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
                        'assets/images/placeholder_2.jpg', // 👈 Fullscreen image
                        fit: BoxFit.fitWidth,
                      ),
                      Container(color: Colors.white.withOpacity(0.0)),
                      Positioned(
                        bottom: 50,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.touch_app,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Tap anywhere to continue",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
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
              : FloatingActionButton.small(
                child: const Icon(Icons.print, color: Colors.white),
                backgroundColor: Colors.black87,
                onPressed: () async {
                  final devices = await PrinterHelper.getBondedDevices();
                  final prefs = await SharedPreferences.getInstance();
                  final lastAddress = prefs.getString("last_selected_printer");

                  if (devices.isEmpty) {
                    showAppSnackBar(context, "No paired printers found.");
                    return;
                  }

                  BluetoothDevice? defaultDevice;
                  try {
                    defaultDevice = devices.firstWhere(
                      (d) => d.address == lastAddress,
                    );
                  } catch (_) {
                    defaultDevice = null;
                  }

                  showModalBottomSheet(
                    context: context,
                    builder: (_) {
                      BluetoothDevice? selected = defaultDevice;
                      return StatefulBuilder(
                        builder: (context, setState) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Printer Settings",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // 🔽 Dropdown with preselected default printer
                                DropdownButton<BluetoothDevice>(
                                  isExpanded: true,
                                  hint: const Text("Select printer"),
                                  value: selected,
                                  items:
                                      devices
                                          .map(
                                            (d) => DropdownMenuItem(
                                              value: d,
                                              child: Text(
                                                d.name ?? "Unnamed Device",
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (val) => setState(() => selected = val),
                                ),
                                const SizedBox(height: 16),

                                // 🔄 Auto Print toggle
                                SwitchListTile(
                                  title: const Text("Auto Print"),
                                  value: _autoPrintEnabled,
                                  onChanged: (val) async {
                                    setState(() => _autoPrintEnabled = val);
                                    await _saveAutoPrintSetting(val);
                                    showAppSnackBar(
                                      context,
                                      val
                                          ? "✅ Auto Print Enabled"
                                          : "❌ Auto Print Disabled",
                                      success: val,
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            selected == null
                                                ? null
                                                : () async {
                                                  await PrinterHelper.saveDefaultPrinter(
                                                    selected!,
                                                  );
                                                  Navigator.pop(context);
                                                  showAppSnackBar(
                                                    context,
                                                    "✅ ${selected!.name ?? 'Printer'} set as default",
                                                    success: true,
                                                  );
                                                },
                                        icon: const Icon(Icons.save),
                                        label: const Text("Save"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.close),
                                        label: const Text("Close"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black54,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
    );
  }

  Widget _buildQrView(Map<String, dynamic> data) {
    final qrImageUrl = data['image']?.toString();
    final isCashOrder = data['method']?.toString().toLowerCase() == 'cash';

    // Common buttons for Print & View Invoice
    Widget _orderActionButtons() {
      if (isOrderLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (order == null) {
                    showAppSnackBar(context, "⚠️ Order not loaded yet.");
                    return;
                  }
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder:
                        (context) => Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: Wrap(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 20,
                                ),
                                child: PrintScreen(order: order!),
                              ),
                            ],
                          ),
                        ),
                  );
                },
                icon: const Icon(Icons.print),
                label: const Text("Print Invoice"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _navigateToSuccess(context, data['orderId']),
                icon: const Icon(Icons.document_scanner),
                label: const Text("View Invoice"),
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
      );
    }

    // CASE 1: Cash Orders
    if (isCashOrder) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.attach_money, color: Colors.green, size: 80),
                const SizedBox(height: 12),
                const Text(
                  "Cash Payment Order",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Order ID: ${data['orderId'] ?? 'N/A'}",
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 20),
                if (isPaid)
                  _orderActionButtons()
                else
                  const Text(
                    "Collect payment in cash from customer.",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // CASE 2: Online Orders
    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: ColorFiltered(
              colorFilter:
                  isPaid
                      ? const ColorFilter.mode(
                        Colors.grey,
                        BlendMode.saturation,
                      )
                      : const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      ),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: LayoutBuilder(
                  builder:
                      (context, constraints) => SizedBox(
                        width: constraints.maxWidth,
                        child: CachedNetworkImage(
                          imageUrl: qrImageUrl ?? '',
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Shimmer.fromColors(
                                baseColor: Colors.grey.shade300,
                                highlightColor: Colors.grey.shade100,
                                child: Container(
                                  width: constraints.maxWidth,
                                  height: double.maxFinite,
                                  color: Colors.white,
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => const Center(
                                child: Text('Failed to load QR image'),
                              ),
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),

        if (!isPaid && !isExpired)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Expires in: ${_formatDuration(remainingTime)}",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),

        if (isPaid)
          Container(
            color: Colors.white.withOpacity(1),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 60),
                  const SizedBox(height: 8),
                  const Text(
                    "Payment Successful",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _orderActionButtons(),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<OrderModelResponse?> _loadOrderDetails(String orderId) async {
    try {
      final api = ApiService(context);
      final res = await api.orderListById(orderId.toString());

      if (res['flag'] == 1 && res['data'] != null) {
        OrderModelResponse? order = OrderModelResponse.fromJson(res['data']);
        order.orderId = orderId.toString();
        return order;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint("❌ Error loading order: $e");
      return null;
    }
  }

  void _handleOrderDelivered(RemoteMessage message) {
    showAppSnackBar(context, "Your order has been delivered successfully!");
  }

  void _navigateToSuccess(BuildContext context, data) {
    Provider.of<AppProvider>(context, listen: false).clearCart();
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

    // 1️⃣ Skip if we already printed this order locally
    if (_recentlyPrinted.contains(orderId)) {
      debugPrint("🟡 Skipping duplicate print for $orderId (cached)");
      return;
    }

    // 2️⃣ Skip if order is older than app session (avoid old prints)
    try {
      final createdAt = DateFormat(
        "yyyy-MM-dd HH:mm:ss",
      ).parseUtc(data['createdAt']);
      if (createdAt.isBefore(
        _sessionStartTime.subtract(const Duration(seconds: 5)),
      )) {
        debugPrint("🟡 Skipping old order $orderId (created before session)");
        return;
      }
    } catch (_) {}

    // 3️⃣ Recheck Firebase for 'printed' status
    final latestSnapshot = await _ordersRef.child(orderId).get();
    final latestData = latestSnapshot.value as Map?;
    if (latestData?['printed'] == true) {
      debugPrint("🟡 Skipping print for $orderId (already marked printed)");
      return;
    }

    // ✅ Proceed with print
    final success = await PrinterHelper.printInvoice(loadedOrder);
    if (success) {
      _recentlyPrinted.add(orderId);
      await _ordersRef.child(orderId).update({'printed': true});
      debugPrint("🟢 Order $orderId printed successfully");
    } else {
      debugPrint("🔴 Failed to print order $orderId");
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
