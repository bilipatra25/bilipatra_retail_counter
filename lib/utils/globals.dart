import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<String> getDeviceId() async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
  return androidInfo.id ??
      ''; // or androidInfo.androidId (deprecated in some cases)
}

typedef NotificationCallback = void Function(RemoteMessage message);

class NotificationEventHandler {
  static NotificationCallback? onOrderDelivered;
}