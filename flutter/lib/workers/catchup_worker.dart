import 'dart:developer' as dev;
import 'package:telephony/telephony.dart';
import '../database/queue_db.dart';
import '../parser/telebirr_parser.dart';
import '../services/sync_service.dart';

class CatchUpWorker {
  /// Scans the device SMS inbox for any Telebirr or CBE messages that may have
  /// arrived while the background service was stopped or device was rebooting.
  static Future<int> scanInboxForMissedReceipts({int lookbackHours = 24}) async {
    try {
      final telephony = Telephony.instance;

      // Check permission
      final hasPermission = await telephony.isSmsCapable;
      if (hasPermission != true) {
        dev.log('Telephony not capable or permission not granted',
            name: 'BirrSync.CatchUpWorker');
        return 0;
      }

      final messages = await telephony.getInboxSms(
        columns: [
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
        ],
        sortOrder: [
          OrderBy(SmsColumn.DATE, sort: Sort.DESC),
        ],
      );

      final cutoffTime = DateTime.now()
          .subtract(Duration(hours: lookbackHours))
          .millisecondsSinceEpoch;

      int newInserted = 0;

      for (final msg in messages) {
        final timestamp = msg.date ?? 0;
        if (timestamp < cutoffTime) {
          // Beyond the lookback window
          break;
        }

        final sender = msg.address ?? '';
        final body = msg.body ?? '';

        if (isFinancialSender(sender, body)) {
          final parsed = parseReceipt(sender, body, timestamp);
          if (parsed != null) {
            final alreadyInDb =
                await QueueDatabase.instance.exists(parsed.transactionId);
            if (!alreadyInDb) {
              final inserted =
                  await QueueDatabase.instance.insertTransaction(parsed);
              if (inserted) {
                newInserted++;
              }
            }
          }
        }
      }

      if (newInserted > 0) {
        dev.log(
          'CatchUpWorker discovered $newInserted missed transactions. Triggering sync...',
          name: 'BirrSync.CatchUpWorker',
        );
        await SyncService.syncPendingQueue();
      }

      return newInserted;
    } catch (e, stack) {
      dev.log(
        'Error during inbox catch-up audit: $e\n$stack',
        name: 'BirrSync.CatchUpWorker',
        error: e,
      );
      return 0;
    }
  }
}
