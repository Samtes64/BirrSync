import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:telephony/telephony.dart';
import '../../database/queue_db.dart';
import '../../services/sync_service.dart';
import '../../workers/catchup_worker.dart';
import '../widgets/metrics_grid.dart';
import '../widgets/status_card.dart';
import '../widgets/transaction_card.dart';
import 'battery_sheet.dart';
import 'settings_sheet.dart';
import 'test_sms_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isServiceRunning = false;
  bool _isSyncing = false;
  String _gatewayId = 'gateway_agent_01';
  String _serverUrl = '';

  Map<String, dynamic> _stats = {
    'total': 0,
    'pending': 0,
    'synced': 0,
    'volume': 0.0,
  };

  List<QueueItem> _transactions = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadState();
    // Refresh stats every 10 seconds while UI is open
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadState(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadState({bool silent = false}) async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    final config = await SyncService.getConfig();
    final stats = await QueueDatabase.instance.getStatistics();
    final txns = await QueueDatabase.instance.getRecentTransactions(limit: 50);

    if (mounted) {
      setState(() {
        _isServiceRunning = isRunning;
        _gatewayId = config['gatewayId'] ?? 'gateway_agent_01';
        _serverUrl = config['serverUrl'] ?? '';
        _stats = stats;
        _transactions = txns;
      });
    }
  }

  Future<void> _toggleService() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke('stopService');
    } else {
      // 1. Request notification permission (Android 13+)
      final notificationsPlugin = FlutterLocalNotificationsPlugin();
      await notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // 2. Request SMS permission
      try {
        final telephony = Telephony.instance;
        await telephony.requestPhoneAndSmsPermissions;
      } catch (_) {}

      // 3. Start foreground service safely
      try {
        await service.startService();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not start service: $e'),
              backgroundColor: Colors.red.shade800,
            ),
          );
        }
      }
    }

    // Give the service a brief moment to update its state
    await Future.delayed(const Duration(milliseconds: 500));
    await _loadState();
  }

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    final result = await SyncService.syncPendingQueue();
    await _loadState();
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor:
              result.success ? const Color(0xFF0D5C3A) : Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _scanMissedInbox() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scanning SMS inbox for missed Telebirr/CBE receipts...'),
        duration: Duration(seconds: 2),
      ),
    );

    final count = await CatchUpWorker.scanInboxForMissedReceipts();
    await _loadState();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Discovered & enqueued $count missed receipts!'
                : 'Inbox scan complete. All receipts are up to date.',
          ),
          backgroundColor: const Color(0xFF0D5C3A),
        ),
      );
    }
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SettingsSheet(onSaved: _loadState),
    );
  }

  void _openBatteryGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const BatteryGuideSheet(),
    );
  }

  void _openTestSmsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => TestSmsDialog(onParsed: _loadState),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.hub_outlined, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            const Text(
              'BirrSync Gateway',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Test SMS Parser',
            onPressed: _openTestSmsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.battery_charging_full),
            tooltip: 'OEM Battery Guide',
            onPressed: _openBatteryGuide,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadState,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    StatusCard(
                      isServiceRunning: _isServiceRunning,
                      gatewayId: _gatewayId,
                      serverUrl: _serverUrl,
                      onToggleService: _toggleService,
                      onSyncNow: _triggerManualSync,
                      onScanInbox: _scanMissedInbox,
                      isSyncing: _isSyncing,
                    ),
                    const SizedBox(height: 12),
                    MetricsGrid(
                      totalCount: _stats['total'] as int? ?? 0,
                      pendingCount: _stats['pending'] as int? ?? 0,
                      syncedCount: _stats['synced'] as int? ?? 0,
                      totalVolume: _stats['volume'] as double? ?? 0.0,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Captured Transactions',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '${_transactions.length} items',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_transactions.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 56,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Transactions Received Yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'BirrSync is actively listening for Telebirr (127) and CBE receipts. When an SMS arrives, it will appear here instantly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _openTestSmsDialog,
                          icon: const Icon(Icons.terminal, size: 16),
                          label: const Text('Simulate Test SMS'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _transactions[index];
                    return TransactionCard(
                      item: item,
                      onRetry: _triggerManualSync,
                    );
                  },
                  childCount: _transactions.length,
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        ),
      ),
    );
  }
}
