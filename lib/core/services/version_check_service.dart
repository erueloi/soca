import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionCheckService {
  static const String versionJsonUrl =
      'https://soca-aacac.web.app/version.json';

  Future<void> checkForUpdates(BuildContext context) async {
    // Only check on Android (or non-web platforms if preferred, but user specified Android)
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final currentPackageInfo = await PackageInfo.fromPlatform();
      final currentVersion = currentPackageInfo.version;

      debugPrint('Checking for updates. Current version: $currentVersion');

      final response = await http.get(Uri.parse(versionJsonUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String? latestVersion = data['version'];
        final String? apkUrl = data['apkUrl'];

        if (latestVersion != null && apkUrl != null) {
          if (_isNewerVersion(currentVersion, latestVersion)) {
            if (context.mounted) {
              _showUpdateDialog(context, latestVersion, apkUrl);
            }
          }
        }
      } else {
        debugPrint('Failed to fetch version info: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  bool _isNewerVersion(String current, String latest) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) {
        return true; // Latest has more parts (e.g. 1.0.1 vs 1.0)
      }
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  void _showUpdateDialog(BuildContext context, String version, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Nova versió disponible'),
        content: Text(
          'Hi ha una nova versió disponible (v$version). Vols descarregar-la?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Més tard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl(url);
            },
            child: const Text('Descarregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }
}
