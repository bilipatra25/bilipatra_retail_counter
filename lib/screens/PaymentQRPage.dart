import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../PrintScreen.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../utils/globals.dart';
import '../models/order_model.dart';

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

  @override
  void initState() {
    super.initState();
    _listenToOrders();
    NotificationEventHandler.onOrderDelivered = _handleOrderDelivered;
  }

  void _listenToOrders() {
    _ordersRef.onChildAdded.listen((event) {
      _updateOrderData(event.snapshot, isNew: true);
    });
    _ordersRef.onChildChanged.listen((event) {
      _updateOrderData(event.snapshot);
    });
  }

  void _updateOrderData(DataSnapshot snapshot, {bool isNew = false}) {
    final rawData = snapshot.value;
    if (rawData == null || rawData is! Map) return;

    // ✅ Convert to Map<String, dynamic>
    final data = Map<String, dynamic>.from(rawData);

    final orderId = data['orderId']?.toString();
    if (orderId == null) return;

    final existingIndex = _orderList.indexWhere(
      (o) => o['orderId'].toString() == orderId,
    );
    if (existingIndex >= 0) {
      _orderList[existingIndex] = data;
    } else {
      _orderList.add(data);
    }

    if (isNew) {
      _setCurrentOrder(data);
    } else if (_currentOrder?['orderId'].toString() == orderId) {
      _setCurrentOrder(data);
    }

    setState(() => isLoading = false);
  }

  void _setCurrentOrder(Map<String, dynamic> data) {
    setState(() {
      _currentOrder = data;
      isPaid = data['paid'] == true;
      isExpired = false;

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
    });
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
                ? Colors.blueAccent
                : isExpired
                ? Colors.grey
                : Colors.green,
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
                  "₹${data['amount'] ?? 0}",
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
    );
  }

  Widget _buildQrView(Map<String, dynamic> data) {
    final qrImageUrl = data['image']?.toString();

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
                        child: Image.network(
                          qrImageUrl ?? '',
                          fit: BoxFit.fitHeight,
                          errorBuilder:
                              (context, error, stackTrace) => const Center(
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
                  color: Colors.green.withOpacity(0.8),
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
                              final appProvider = Provider.of<AppProvider>(
                                context,
                                listen: false,
                              );
                              final user = appProvider.user;

                              final order = await _loadOrderDetails(
                                data['orderId'].toString(),
                              );
                              if (order == null) return;

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
                                            child: PrintScreen(
                                              user: user,
                                              order: order,
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
        final order = OrderModelResponse.fromJson(res['data']);
        return order;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load order details.")),
        );
        return null;
      }
    } catch (e) {
      print("❌ Error loading order: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error loading order: $e")));
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
