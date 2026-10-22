import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../database/queue_db.dart';

class TransactionCard extends StatelessWidget {
  final QueueItem item;
  final VoidCallback? onRetry;

  const TransactionCard({
    super.key,
    required this.item,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    final isTelebirr = item.provider == 'TELEBIRR';
    final isSynced = item.syncStatus == 'SYNCED';
    final isFailed = item.syncStatus == 'FAILED';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isTelebirr
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFEDE7F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.provider,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isTelebirr
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF512DA8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: item.transactionId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ${item.transactionId}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            item.transactionId,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.copy, size: 14, color: Colors.grey.shade500),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  'ETB ${currencyFormat.format(item.amount)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D5C3A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (item.senderName != null && item.senderName!.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    item.senderName!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.maskedPhone != null && item.maskedPhone!.isNotEmpty)
                    Text(
                      ' (${item.maskedPhone})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(
                      DateTime.fromMillisecondsSinceEpoch(item.timestamp)),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSynced
                        ? Colors.green.shade50
                        : (isFailed ? Colors.red.shade50 : Colors.orange.shade50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSynced
                          ? Colors.green.shade300
                          : (isFailed
                              ? Colors.red.shade300
                              : Colors.orange.shade300),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSynced
                            ? Icons.check_circle_outline
                            : (isFailed
                                ? Icons.error_outline
                                : Icons.schedule_outlined),
                        size: 12,
                        color: isSynced
                            ? Colors.green.shade700
                            : (isFailed
                                ? Colors.red.shade700
                                : Colors.orange.shade800),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.syncStatus,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSynced
                              ? Colors.green.shade700
                              : (isFailed
                                  ? Colors.red.shade700
                                  : Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
