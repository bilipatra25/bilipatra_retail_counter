import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';

class AppUpdateHelper {
  static Future<void> checkAppUpdate(BuildContext context) async {
    try {
      final apiService = ApiService(context);
      final config = await apiService.fetchAppConfig();
      final info = await PackageInfo.fromPlatform();

      final String currentVersion = info.version;
      final String minVersion = config['retail_app_minimum_version'] ?? '0.0.0';
      final String latestVersion = config['retail_app_version'] ?? '0.0.0';
      final String apkUrl = config['retail_app_url'] ?? '';

      debugPrint('\x1B[34m📱 Version Check -> Current: $currentVersion | Min: $minVersion | Latest: $latestVersion\x1B[0m');

      // 🔴 FORCE UPDATE
      if (_compareVersions(currentVersion, minVersion) < 0) {
        if (context.mounted) {
          _showUpdateBottomSheet(context, forceUpdate: true, apkUrl: apkUrl);
        }
        return;
      }

      // 🟡 OPTIONAL UPDATE
      if (_compareVersions(currentVersion, latestVersion) < 0) {
        if (context.mounted) {
          _showUpdateBottomSheet(context, forceUpdate: false, apkUrl: apkUrl);
        }
      }
    } catch (e) {
      debugPrint("❌ Update check failed: $e");
    }
  }

  static int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map(int.parse).toList();
    final v2Parts = v2.split('.').map(int.parse).toList();

    final maxLength = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;

    for (int i = 0; i < maxLength; i++) {
      final v1Part = i < v1Parts.length ? v1Parts[i] : 0;
      final v2Part = i < v2Parts.length ? v2Parts[i] : 0;

      if (v1Part > v2Part) return 1;
      if (v1Part < v2Part) return -1;
    }
    return 0;
  }

  // 🟢 Reverted to Bottom Sheet, but kept the PopScope and drag locks for security
  static void _showUpdateBottomSheet(BuildContext context, {required bool forceUpdate, required String apkUrl}) {
    showModalBottomSheet(
      context: context,
      isDismissible: !forceUpdate, // 🔒 Prevents tapping outside to dismiss
      enableDrag: !forceUpdate,    // 🔒 Prevents swiping down to dismiss
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return PopScope(
          canPop: !forceUpdate, // 🔒 Prevents Android physical back button from bypassing forced updates
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Optional Drag Handle for UI polish
                  if (!forceUpdate)
                    Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  Icon(
                      forceUpdate ? Icons.system_security_update_warning : Icons.system_update,
                      size: 60,
                      color: forceUpdate ? Colors.red.shade600 : Colors.green.shade700
                  ),
                  const SizedBox(height: 16),
                  Text(
                    forceUpdate ? "Critical Update Required" : "App Update Available",
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    forceUpdate
                        ? "You must update the POS app to the latest version to continue processing orders securely."
                        : "A new version of the POS is available with bug fixes and improvements.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      if (!forceUpdate) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text("Later", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openApk(context, apkUrl),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: forceUpdate ? Colors.red.shade600 : Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.download, size: 20),
                          label: const Text("Update Now", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> _openApk(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);

      // First try: open in browser (Downloads the APK directly)
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!launched) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      debugPrint("Failed to open APK url: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Unable to open update link. Check your internet connection."), backgroundColor: Colors.red),
        );
      }
    }
  }
}