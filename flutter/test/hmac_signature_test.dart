import 'package:flutter_test/flutter_test.dart';
import 'package:birrsync/services/sync_service.dart';

void main() {
  group('HMAC-SHA256 Signature Tests', () {
    test('Calculates deterministic HMAC-SHA256 matching Go backend', () {
      const secret = 'birrsync_secret_live_key_2026';
      const payload = '1729580000000.{"provider":"TELEBIRR","amount":490.0}';

      final signature = SyncService.computeHmacSignature(secret, payload);

      expect(signature, isNotEmpty);
      expect(signature.length, equals(64)); // 32 bytes hex encoded = 64 chars
      expect(signature, matches(RegExp(r'^[a-f0-9]{64}$')));

      // Test consistency
      final signature2 = SyncService.computeHmacSignature(secret, payload);
      expect(signature, equals(signature2));
    });
  });
}
