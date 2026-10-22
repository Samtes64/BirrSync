import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/queue_db.dart';

class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;

  SyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
  });
}

class SyncService {
  static const String keyServerUrl = 'birrsync_server_url';
  static const String keyGatewayId = 'birrsync_gateway_id';
  static const String keyGatewaySecret = 'birrsync_gateway_secret';
  static const String keyLastSync = 'birrsync_last_sync';
  static const String keyLastHeartbeat = 'birrsync_last_heartbeat';

  static const String defaultUrl = 'http://10.142.227.81:8080';
  static const String defaultGatewayId = 'gateway_agent_01';
  static const String defaultGatewaySecret = 'birrsync_secret_live_key_2026';

  /// Computes HMAC-SHA256 hex string over payload
  static String computeHmacSignature(String secretKey, String payload) {
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(payload);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  /// Gets stored gateway configuration
  static Future<Map<String, String>> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'serverUrl': prefs.getString(keyServerUrl) ?? defaultUrl,
      'gatewayId': prefs.getString(keyGatewayId) ?? defaultGatewayId,
      'gatewaySecret':
          prefs.getString(keyGatewaySecret) ?? defaultGatewaySecret,
    };
  }

  /// Saves gateway configuration
  static Future<void> saveConfig({
    required String serverUrl,
    required String gatewayId,
    required String gatewaySecret,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // Normalize server URL (remove trailing slash)
    String cleanUrl = serverUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    await prefs.setString(keyServerUrl, cleanUrl);
    await prefs.setString(keyGatewayId, gatewayId.trim());
    await prefs.setString(keyGatewaySecret, gatewaySecret.trim());
  }

  /// Synchronizes all pending transactions in local SQLite queue with cloud server
  static Future<SyncResult> syncPendingQueue() async {
    try {
      final config = await getConfig();
      final serverUrl = config['serverUrl']!;
      final gatewayId = config['gatewayId']!;
      final secretKey = config['gatewaySecret']!;

      if (serverUrl.isEmpty || gatewayId.isEmpty || secretKey.isEmpty) {
        return SyncResult(
          success: false,
          message: 'Server URL or Gateway credentials not configured',
        );
      }

      final pendingItems = await QueueDatabase.instance.getPendingTransactions();
      if (pendingItems.isEmpty) {
        return SyncResult(
          success: true,
          message: 'Local queue is clear. No pending receipts.',
          syncedCount: 0,
        );
      }

      int successCount = 0;
      final client = http.Client();

      try {
        for (final item in pendingItems) {
          final bodyJson = jsonEncode(item.toApiJson());
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final payloadToSign = '$timestamp.$bodyJson';
          final signature = computeHmacSignature(secretKey, payloadToSign);

          final url = Uri.parse('$serverUrl/v1/gateway/ingest');
          final response = await client.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'X-Gateway-ID': gatewayId,
              'X-Gateway-Timestamp': timestamp.toString(),
              'X-Gateway-Signature': signature,
            },
            body: bodyJson,
          );

          if (response.statusCode == 200) {
            await QueueDatabase.instance.markAsSynced(item.transactionId);
            successCount++;
          } else {
            await QueueDatabase.instance.markAsFailed(
              item.transactionId,
              'HTTP ${response.statusCode}: ${response.body}',
            );
          }
        }
      } finally {
        client.close();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          keyLastSync, DateTime.now().millisecondsSinceEpoch);

      return SyncResult(
        success: true,
        message: 'Successfully synchronized $successCount of ${pendingItems.length} transactions.',
        syncedCount: successCount,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Sync network error: $e',
      );
    }
  }

  /// Sends heartbeat ping with device telemetry
  static Future<bool> sendHeartbeat({int batteryLevel = 100}) async {
    try {
      final config = await getConfig();
      final serverUrl = config['serverUrl']!;
      final gatewayId = config['gatewayId']!;
      final secretKey = config['gatewaySecret']!;

      final bodyJson = jsonEncode({
        'battery_level': batteryLevel,
        'app_version': '1.0.0',
      });

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final payloadToSign = '$timestamp.$bodyJson';
      final signature = computeHmacSignature(secretKey, payloadToSign);

      final url = Uri.parse('$serverUrl/v1/gateway/heartbeat');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Gateway-ID': gatewayId,
          'X-Gateway-Timestamp': timestamp.toString(),
          'X-Gateway-Signature': signature,
        },
        body: bodyJson,
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
            keyLastHeartbeat, DateTime.now().millisecondsSinceEpoch);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Tests connectivity and HMAC authentication against configured server
  static Future<SyncResult> testConnection({
    required String serverUrl,
    required String gatewayId,
    required String gatewaySecret,
  }) async {
    try {
      String cleanUrl = serverUrl.trim();
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      final bodyJson = jsonEncode({'battery_level': 100, 'test': true});
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final payloadToSign = '$timestamp.$bodyJson';
      final signature = computeHmacSignature(gatewaySecret, payloadToSign);

      final response = await http
          .post(
            Uri.parse('$cleanUrl/v1/gateway/heartbeat'),
            headers: {
              'Content-Type': 'application/json',
              'X-Gateway-ID': gatewayId,
              'X-Gateway-Timestamp': timestamp.toString(),
              'X-Gateway-Signature': signature,
            },
            body: bodyJson,
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        return SyncResult(
          success: true,
          message: 'Connection verified! HMAC authenticated successfully.',
        );
      } else if (response.statusCode == 401) {
        return SyncResult(
          success: false,
          message: 'Authentication failed: Invalid Gateway ID or Secret Key.',
        );
      } else {
        return SyncResult(
          success: false,
          message: 'Server returned HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Could not reach server: $e',
      );
    }
  }
}
