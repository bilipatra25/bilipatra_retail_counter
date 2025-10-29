import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
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

    final existingIndex =
    _orderList.indexWhere((o) => o['orderId'].toString() == orderId);
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
          final utc = DateFormat("yyyy-MM-dd HH:mm:ss").parseUtc(data['createdAt']);
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
    final title = isPaid
        ? "Payment Completed"
        : isExpired
        ? "QR Expired"
        : "Complete Payment";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isPaid
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "₹${data['amount'] ?? 0}",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
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
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
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
      body: isLoading
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
              colorFilter: isPaid
                  ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                  : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: LayoutBuilder(
                  builder: (context, constraints) => SizedBox(
                    width: constraints.maxWidth,
                    child: Image.network(
                      qrImageUrl ?? '',
                      fit: BoxFit.fitHeight,
                      errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Text('Failed to load QR image')),
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
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            color: Colors.black.withOpacity(0.4),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 60),
                  SizedBox(height: 8),
                  Text(
                    "Payment Successful",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  void _handleOrderDelivered(RemoteMessage message) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Your order has been delivered successfully!"),
      ),
    );
  }
}
