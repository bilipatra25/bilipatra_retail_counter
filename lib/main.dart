import 'package:bilipatra_retail_counter/services/api_service.dart';
import 'package:bilipatra_retail_counter/services/invoice_generator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'providers/app_provider.dart';
import 'routes/app_router.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Get the token just for debug
  String? token = await FirebaseMessaging.instance.getToken();
  print('🔔 FCM Token: $token');

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("🔔 Foreground notification: ${message.notification?.title}");
  });

  runApp(const BilipatraApp());
}

class BilipatraApp extends StatelessWidget {
  const BilipatraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Bilipatra Retail Counter',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green.shade600),
          useMaterial3: true,
        ),
        routerConfig: appRouter,
      ),
    );
  }
}
