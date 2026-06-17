import 'package:flutter/material.dart';
import 'package:bilipatra_retail_counter/screens/pos/pos_dashboard_screen.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/PaymentImageScreen.dart';
import '../screens/confirm_order_screen.dart';
import '../screens/invoice_webview_screen.dart';
import '../screens/order_success_screen.dart';
import '../screens/product_list_screen.dart';
import '../screens/user_form_screen.dart';
import '../screens/login_screen.dart';

GoRouter createAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isInitialized = authProvider.isInitialized;
      final isLoggedIn = authProvider.isLoggedIn;
      
      final isGoingToLogin = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      // 1. If not initialized, force them to the splash screen
      if (!isInitialized) {
        return isSplash ? null : '/splash';
      }

      // 2. If initialized and NOT logged in
      if (!isLoggedIn) {
        return isGoingToLogin ? null : '/login';
      }

      // 3. If initialized and IS logged in
      if (isLoggedIn && (isGoingToLogin || isSplash)) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Colors.green),
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'posDashboard',
        builder: (context, state) => const PosDashboardScreen(),
      ),
      GoRoute(
        path: '/order-success/:orderId',
        name: 'orderSuccess',
        builder: (context, state) {
          final orderId = int.parse(state.pathParameters['orderId']!);
          return OrderSuccessScreen(orderId: orderId);
        },
      ),
      GoRoute(
        name: 'invoiceView',
        path: '/invoiceView/:url',
        builder: (context, state) {
          final url = state.pathParameters['url']!;
          return InvoiceWebViewScreen(url: url);
        },
      ),
    ],
  );
}
