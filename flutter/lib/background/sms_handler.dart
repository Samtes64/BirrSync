import 'dart:developer' as dev;
import 'package:telephony/telephony.dart';
import '../database/queue_db.dart';
import '../parser/telebirr_parser.dart';
import '../services/sync_service.dart';

/// Top-level background entry point called by Android telephony BroadcastReceiver
/// even when the UI is closed or the device is locked.
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  try {
    final sender = message.address ?? '';
    final body = message.body ?? '';
    final timestamp = message.date ?? DateTime.now().millisecondsSinceEpoch;

    dev.log(
      'SMS received from: $sender',
      name: 'BirrSync.SMSHandler',
    );

    // Filter only financial providers (Telebirr 127 or CBE)
    if (isFinancialSender(sender, body)) {
      final parsed = parseReceipt(sender, body, timestamp);
      if (parsed != null) {
        dev.log(
          'Parsed transaction: ${parsed.transactionId} for ETB ${parsed.amount}',
          name: 'BirrSync.SMSHandler',
        );

        // 1. Enqueue to local SQLite database (resilient to offline conditions)
        final inserted =
            await QueueDatabase.instance.insertTransaction(parsed);

        if (inserted) {
          // 2. Trigger instant HTTP sync worker with cloud server
          await SyncService.syncPendingQueue();
        }
      }
    }
  } catch (e, stack) {
    dev.log(
      'Error in backgroundMessageHandler: $e\n$stack',
      name: 'BirrSync.SMSHandler',
      error: e,
    );
  }
}
