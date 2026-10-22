import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final bool isServiceRunning;
  final String gatewayId;
  final String serverUrl;
  final VoidCallback onToggleService;
  final VoidCallback onSyncNow;
  final VoidCallback onScanInbox;
  final bool isSyncing;

  const StatusCard({
    super.key,
    required this.isServiceRunning,
    required this.gatewayId,
    required this.serverUrl,
    required this.onToggleService,
    required this.onSyncNow,
    required this.onScanInbox,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = isServiceRunning;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isOnline
                ? [const Color(0xFF0D5C3A), const Color(0xFF1B8A5A)]
                : [const Color(0xFF333333), const Color(0xFF4A4A4A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.greenAccent : Colors.orangeAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isOnline ? Colors.greenAccent : Colors.orangeAccent)
                                .withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isOnline ? 'SERVICE ACTIVE' : 'SERVICE STOPPED',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: onToggleService,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: Icon(
                    isOnline ? Icons.stop_circle_outlined : Icons.play_circle_fill,
                    size: 18,
                  ),
                  label: Text(isOnline ? 'Stop' : 'Start'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Gateway: $gatewayId',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              serverUrl.isNotEmpty ? serverUrl : 'No server URL configured',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isSyncing ? null : onSyncNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0D5C3A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0D5C3A),
                            ),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: Text(
                      isSyncing ? 'Syncing...' : 'Sync Queue',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onScanInbox,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white60),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                    label: const Text('Scan Inbox'),
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
