import 'package:flutter_test/flutter_test.dart';
import 'package:birrsync/parser/telebirr_parser.dart';
import 'package:birrsync/services/sync_service.dart';

void main() {
  test('BirrSync Agent Core Smoke Test', () {
    // 1. Verify parser works
    const testSms =
        'You have received ETB 100.00 from Test User(2519****0001). Your transaction number is TESTTXN001.';
    final parsed = parseReceipt('127', testSms, 1729580000000);
    expect(parsed, isNotNull);
    expect(parsed!.amount, equals(100.00));
    expect(parsed.transactionId, equals('TESTTXN001'));

    // 2. Verify HMAC signing
    final signature =
        SyncService.computeHmacSignature('test_secret', 'test_payload');
    expect(signature, isNotEmpty);
    expect(signature.length, equals(64));
  });
}
