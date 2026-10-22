import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MetricsGrid extends StatelessWidget {
  final int totalCount;
  final int pendingCount;
  final int syncedCount;
  final double totalVolume;

  const MetricsGrid({
    super.key,
    required this.totalCount,
    required this.pendingCount,
    required this.syncedCount,
    required this.totalVolume,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Synced Volume',
            value: 'ETB ${currencyFormat.format(totalVolume)}',
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF1B8A5A),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: 'Pending Queue',
            value: pendingCount.toString(),
            icon: Icons.hourglass_top_outlined,
            color: pendingCount > 0 ? Colors.orange.shade700 : Colors.blueGrey,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: 'Total Processed',
            value: totalCount.toString(),
            icon: Icons.receipt_long_outlined,
            color: Colors.indigo.shade600,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
