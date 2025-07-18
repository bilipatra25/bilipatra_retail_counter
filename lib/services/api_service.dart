import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../models/common_response.dart';
import '../models/product.dart';
import '../utils/logger.dart';

class ApiService {
  final BuildContext context;

  // static const String baseUrl = 'http://localhost:8084/storelocate';
  // static const String baseUrl = 'http://13.233.150.163:8084/storelocate';
  // static const String baseUrl = 'http://172.20.10.4:8084/storelocate';
  // static const String baseUrl = 'http://192.168.31.76:8084/storelocate'; //Local
  static const String baseUrl = 'https://b12greenfood.shop:3003/storelocate'; //Live
  // static const String baseUrl = 'http://3.108.43.136:8084/storelocate'; //Dev
  ApiService(this.context);

  void _logRequest(
    String endpoint,
    Map<String, dynamic> body,
    Map<String, String> header,
  ) {
    _printLog("🟢 [API REQUEST] 🌍 Endpoint: $endpoint");
    _printLog("📦 Body: ${jsonEncode(body)}");
    _printLog("📝 Headers: ${jsonEncode(header)}");
  }

  void _logResponse(String endpoint, http.Response response) {
    final status = response.statusCode;
    String statusEmoji = (status == 200) ? "✅" : "❌";

    _printLog("$statusEmoji [API RESPONSE] 🌍 Endpoint: $endpoint");
    _printLog("📡 Status Code: $status");
    _printLog("📜 Body: ${response.body}");
  }

  void _logError(String endpoint, dynamic error) {
    _printLog("🚨 [API ERROR] 🌍 Endpoint: $endpoint");
    _printLog("❌ Error: $error");
  }

  // Utility function for formatted logging with colors
  void _printLog(String message) {
    debugPrint('\x1B[34m$message\x1B[0m', wrapWidth: 1024);
  }

  // Common Headers
  Future<Map<String, String>> _getHeaders() async {
    // final String? token = await SharedPrefsUtil.getToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      // if (token != null) 'authorization': token,
    };
  }

  // Session Expired Handler (Singleton Approach)
  static bool _isSessionDialogVisible = false;

  void _showSessionExpiredDialog(BuildContext context) {
    if (_isSessionDialogVisible) return;
    _isSessionDialogVisible = true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Session Expired"),
          content: Text("Your session has expired. Please log in again."),
          actions: [
            TextButton(
              onPressed: () {
                _isSessionDialogVisible = false;
                context.pop();
                // context.go(AppRoutePaths.login);
              },
              child: Text("Ok"),
            ),
          ],
        );
      },
    );
  }

  // Generic API Request Handler
  Future<Map<String, dynamic>> _postRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$baseUrl/$endpoint');
    final headers = await _getHeaders();

    // Check internet connection before making request
    if (!await _isConnected()) {
      _showNoInternetDialog(context);
      return CommonResponse(
        flag: 0,
        code: 500,
        message: "No internet connection",
      ).toJson();
    }

    _logRequest(url.toString(), body, headers);

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(Duration(seconds: 30)); // Increased timeout

      _logResponse(url.toString(), response);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (data['code'] == 401) {
          _showSessionExpiredDialog(context);
          return CommonResponse(
            flag: 0,
            code: 401,
            message: "Session expired",
          ).toJson();
        }
        return data;
      } else {
        throw ApiException(
          response.statusCode,
          data['message'] ?? 'Unknown error',
        );
      }
    } on SocketException {
      throw ApiException(500, "No internet connection");
    } on TimeoutException {
      throw ApiException(500, "Request timed out");
    } catch (e) {
      _logError(url.toString(), e);
      throw ApiException(500, "Unexpected error: $e");
    }
  }

  Future<Map<String, dynamic>> _makeRequest(
    HttpMethod method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? multipartFields,
    Map<String, File>? multipartFiles,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/$endpoint',
    ).replace(queryParameters: queryParams);
    final headers = await _getHeaders();

    if (!await _isConnected()) {
      /*if (mounted)*/
      _showNoInternetDialog(context);
      return CommonResponse(
        flag: 0,
        code: 500,
        message: "No internet connection",
      ).toJson();
    }

    _logRequest(
      uri.toString(),
      body ?? queryParams ?? multipartFields!,
      headers,
    );

    try {
      late http.Response response;

      switch (method) {
        case HttpMethod.get:
          response = await http
              .get(uri, headers: headers)
              .timeout(Duration(seconds: 30));
          break;

        case HttpMethod.post:
          response = await http
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(Duration(seconds: 30));
          break;

        case HttpMethod.put:
          response = await http
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(Duration(seconds: 30));
          break;

        case HttpMethod.delete:
          response = await http
              .delete(uri, headers: headers, body: jsonEncode(body))
              .timeout(Duration(seconds: 30));
          break;

        case HttpMethod.multipart:
          var request = http.MultipartRequest('POST', uri);
          request.headers.addAll(headers);
          multipartFields?.forEach((key, value) {
            request.fields[key] = value;
          });
          final files = multipartFiles ?? {};

          for (var entry in files.entries) {
            final file = await http.MultipartFile.fromPath(
              entry.key,
              entry.value.path,
            );
            request.files.add(file);
          }

          var streamed = await request.send();
          response = await http.Response.fromStream(streamed);
          break;
      }

      _logResponse(uri.toString(), response);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['code'] == 401 /*&& mounted*/ ) {
          _showSessionExpiredDialog(context);
          return CommonResponse(
            flag: 0,
            code: 401,
            message: "Session expired",
          ).toJson();
        }
        return data;
      } else {
        throw ApiException(
          response.statusCode,
          data['message'] ?? 'Unknown error',
        );
      }
    } on SocketException {
      throw ApiException(500, "No internet connection");
    } on TimeoutException {
      throw ApiException(500, "Request timed out");
    } catch (e) {
      _logError(uri.toString(), e);
      throw ApiException(500, "Unexpected error: $e");
    }
  }

  Future<bool> _isConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();

    // Step 1: Check if there is an active network connection (WiFi/Mobile)
    if (!connectivityResult.contains(ConnectivityResult.mobile) &&
        !connectivityResult.contains(ConnectivityResult.wifi)) {
      return false; // No network detected
    }

    // Step 2: Verify actual internet access by making a lightweight test request
    try {
      final result = await InternetAddress.lookup(
        '8.8.8.8',
      ); // Google's Public DNS
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false; // No internet access
    }
  }

  bool _isDialogShowing = false;

  void _showNoInternetDialog(BuildContext context) {
    if (_isDialogShowing) return;

    _isDialogShowing = true;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("No Internet"),
            content: const Text(
              "Please check your internet connection and try again.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _isDialogShowing = false; // Reset the flag
                },
                child: const Text("OK"),
              ),
            ],
          ),
    ).then((_) {
      _isDialogShowing =
          false; // Also reset if dialog is dismissed via back button
    });
  }

  ///Examples of different request method ------
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    return await _makeRequest(
      HttpMethod.get,
      "user/profile",
      queryParams: {'user_id': userId},
    );
  }

  Future<Map<String, dynamic>> loginExample(
    String mobile,
    String password,
  ) async {
    return await _makeRequest(
      HttpMethod.post,
      "auth/login",
      body: {'mobile': mobile, 'password': password},
    );
  }

  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    return await _makeRequest(HttpMethod.put, "user/update", body: profileData);
  }

  Future<Map<String, dynamic>> deleteAccount(String userId) async {
    return await _makeRequest(
      HttpMethod.delete,
      "user/delete",
      body: {'user_id': userId},
    );
  }

  Future<Map<String, dynamic>> uploadImage(File imageFile) async {
    return await _makeRequest(
      HttpMethod.multipart,
      "user/upload",
      multipartFields: {'description': 'Profile picture'},
      multipartFiles: {'image': imageFile},
    );
  }

  ///Example Ends ------

  Future<Map<String, dynamic>> customerLogin(
    String customerName,
    String mobile,
    String address,
  ) async {
    return await _postRequest("retailcounter_customer/v1/apiinsert", {
      'customer_name': customerName,
      'mobile_no': int.parse(mobile),
      'address': address,
    });
  }

  Future<Map<String, dynamic>> saveFcmToken(
       String deviceId,
       String fcmToken,
       String platform,
  ) async {
    return await _postRequest("retail_fcm_token/v1/saveretailfcmtoken", {
      'device_id': deviceId,
      'fcm_token': fcmToken,
      'platform': platform,
    });
  }

  Future<http.Response> insertUser(Map<String, dynamic> userData) async {
    final url = '$baseUrl/user/v1/apiinsert';
    final headers = {'Content-Type': 'application/json; charset=UTF-8'};
    Logger.logRequest(url, headers, userData);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(userData),
      );
      Logger.logResponse(response.statusCode, response.body);
      return response;
    } catch (e) {
      Logger.log('Error: $e');
      throw Exception('Failed to insert user: $e');
    }
  }

  Future<List<ProductModel>> productList(int pageIndex, int pageSize) async {
    final response = await _postRequest("product_detail/v1/apiselectall", {
      'pageIndex': pageIndex,
      'pageSize': pageSize,
      'searchParam': {'global_search': '', 'product_name': ''},
    });
    if (response['flag'] == 1 && response['code'] == 200) {
      final List<dynamic> results = response['data']['result'];
      return results.map((product) => ProductModel.fromJson(product)).toList();
    } else {
      throw Exception('Failed to load products: ${response['message']}');
    }
  }

  Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> data) async {
    final response = await _postRequest(
      'retailcounter_order/v1/apiinsert',
      data,
    );
    if (response['flag'] == 1 && response['code'] == 200) {
      return response['data'];
    } else {
      throw Exception('Order failed: ${response['message']}');
    }
  }

  Future<Map<String, dynamic>> orderListById(String orderId) async {
    return await _postRequest("retailcounter_order/v1/orderlistbyid", {
      'order_id': orderId,
    });
  }
}

// Custom API Exception
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'API Error ($statusCode): $message';
}

enum HttpMethod { get, post, put, delete, multipart }
