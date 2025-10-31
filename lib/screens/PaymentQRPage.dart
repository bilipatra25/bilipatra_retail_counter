import 'dart:async';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../PrintScreen.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../utils/PrinterHelper.dart';
import '../utils/globals.dart';
import '../models/order_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

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

  Timer? countdownTimer;
  Duration remainingTime = const Duration(hours: 2);
  OrderModelResponse? order;

  StreamSubscription<DatabaseEvent>? _addedSub;
  StreamSubscription<DatabaseEvent>? _changedSub;
  bool _autoPrintEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadAutoPrintSetting();
    NotificationEventHandler.onOrderDelivered = _handleOrderDelivered;
    _listenToOrders();
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

  @override
  void dispose() {
    // Cancel Firebase subscriptions to avoid late setState()
    _addedSub?.cancel();
    _changedSub?.cancel();
    NotificationEventHandler.onOrderDelivered = null;
    super.dispose();
  }

  void _updateOrderData(DataSnapshot snapshot, {bool isNew = false}) async {
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
    if (_orderList.length > 5) {
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

    // Fetch full order details
    try {
      final loadedOrder = await _loadOrderDetails(data['orderId'].toString());
      if (loadedOrder == null) {
        debugPrint("⚠️ Failed to load order details");
        return;
      }

      setState(() => order = loadedOrder);

      // 🔹 Print invoice only when needed
      if (_autoPrintEnabled && shouldAutoPrint) {
        final success = await PrinterHelper.printInvoice(loadedOrder);

        // 🔸 Mark as printed in Firebase after successful print
        if (success) {
          await _ordersRef.child(data['orderId'].toString()).update({
            'printed': true,
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? "✅ Invoice sent to printer"
                    : "⚠️ Failed to print. Check printer connection.",
              ),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Error during order fetch/print: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
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
      appBar: AppBar(
        backgroundColor:
            isPaid
                ? Colors.green
                : isExpired
                ? Colors.grey
                : Colors.blueAccent,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (data != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "#${data['orderId']} - ${data['name'] ?? ''}",
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            if (data != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
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
        actions: [
          IconButton(
            tooltip: _autoPrintEnabled ? "Auto Print: ON" : "Auto Print: OFF",
            icon: Icon(
              _autoPrintEnabled ? Icons.print : Icons.print_disabled,
              color: _autoPrintEnabled ? Colors.white : Colors.white70,
            ),
            onPressed: () async {
              final newValue = !_autoPrintEnabled;
              setState(() => _autoPrintEnabled = newValue);
              await _saveAutoPrintSetting(newValue);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    newValue ? "✅ Auto Print Enabled" : "❌ Auto Print Disabled",
                  ),
                  backgroundColor: newValue ? Colors.green : Colors.orange,
                ),
              );
            },
          ),
          if (_orderList.isNotEmpty)
            PopupMenuButton<Map<String, dynamic>>(
              icon: const Icon(Icons.list_alt),
              onSelected: (order) {
                _setCurrentOrder(order);
              },
              itemBuilder: (context) {
                return _orderList.map((order) {
                  final id = order['orderId'];
                  final name = order['name'] ?? '';
                  final paid = order['paid'] == true;
                  return PopupMenuItem(
                    value: order,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("#$id - $name"),
                        if (paid)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : data == null
              ? const Center(child: Text("No payment QR available yet."))
              : _buildQrView(data),
      floatingActionButton: FloatingActionButton.small(
        child: const Icon(Icons.print, color: Colors.white),
        backgroundColor: Colors.black87,
        onPressed: () async {
          final devices = await PrinterHelper.getBondedDevices();
          final prefs = await SharedPreferences.getInstance();
          final lastAddress = prefs.getString("last_selected_printer");

          if (devices.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No paired printers found.")),
            );
            return;
          }

          BluetoothDevice? defaultDevice;
          try {
            defaultDevice = devices.firstWhere((d) => d.address == lastAddress);
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
                          "Select Default Printer",
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
                                      child: Text(d.name ?? "Unnamed Device"),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) => setState(() => selected = val),
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
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "✅ ${selected!.name ?? 'Printer'} set as default",
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
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
                                    borderRadius: BorderRadius.circular(8),
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
                                    borderRadius: BorderRadius.circular(8),
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

    // ✅ CASE 1: Cash Orders (No QR image)
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
                  Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 50,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Payment Confirmed",
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (order == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "⚠️ Order not loaded yet.",
                                        ),
                                      ),
                                    );
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
                                            bottom:
                                                MediaQuery.of(
                                                  context,
                                                ).viewInsets.bottom,
                                          ),
                                          child: Wrap(
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 20,
                                                    ),
                                                child: PrintScreen(
                                                  order: order!,
                                                ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    () => _navigateToSuccess(
                                      context,
                                      data['orderId'],
                                    ),
                                icon: const Icon(Icons.document_scanner),
                                label: const Text("View Invoice"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
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

    // ✅ CASE 2: Online Orders with QR image
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (order == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("⚠️ Order not loaded yet."),
                                  ),
                                );
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
                                        bottom:
                                            MediaQuery.of(
                                              context,
                                            ).viewInsets.bottom,
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
                            onPressed:
                                () => _navigateToSuccess(
                                  context,
                                  data['orderId'],
                                ),
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
                  ),
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
        return OrderModelResponse.fromJson(res['data']);
      } else {
        return null;
      }
    } catch (e) {
      debugPrint("❌ Error loading order: $e");
      return null;
    }
  }

  void _handleOrderDelivered(RemoteMessage message) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Your order has been delivered successfully!"),
      ),
    );
  }

  void _navigateToSuccess(BuildContext context, data) {
    context.pushNamed(
      'orderSuccess',
      pathParameters: {'orderId': data.toString()},
    );
  }
}
