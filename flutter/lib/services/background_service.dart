import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:telephony/telephony.dart';
import '../background/sms_handler.dart';
import '../services/sync_service.dart';
import '../workers/catchup_worker.dart';

const String kNotificationChannelId = 'birrsync_gateway_channel';
const int kNotificationId = 888;

/// Configures and initializes the persistent Android foreground service
Future<void> initializeBackgroundService() async {
  try {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      kNotificationChannelId,
      'BirrSync Gateway Active',
      description: 'Listening for incoming Telebirr and CBE payments',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onServiceStart,
        autoStart: false, // Set to false to prevent crash on Android 12+ before Activity resumes
        isForegroundMode: true,
        notificationChannelId: kNotificationChannelId,
        initialNotificationTitle: 'BirrSync Gateway Running',
        initialNotificationContent: 'Waiting for incoming payment receipts...',
        foregroundServiceNotificationId: kNotificationId,
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
  } catch (e, stack) {
    dev.log('Failed to configure background service: $e\n$stack',
        name: 'BirrSync.Service', error: e);
  }
}

/// Top-level foreground service entry point
@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) {
  dev.log('BirrSync Background Service Started', name: 'BirrSync.Service');

  // Listen for service stop signal from UI
  service.on('stopService').listen((event) {
    dev.log('Stopping background service...', name: 'BirrSync.Service');
    service.stopSelf();
  });

  // Listen for manual sync trigger from UI
  service.on('triggerSync').listen((event) async {
    await SyncService.syncPendingQueue();
  });

  // Initialize SMS listener
  try {
    final Telephony telephony = Telephony.instance;
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        backgroundMessageHandler(message);
      },
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );
    dev.log('Telephony SMS listener initialized.', name: 'BirrSync.Service');
  } catch (e) {
    dev.log('Failed to start SMS listener: $e', name: 'BirrSync.Service');
  }

  // Initial catch-up and heartbeat
  CatchUpWorker.scanInboxForMissedReceipts();
  SyncService.sendHeartbeat();

  // Periodic 15-minute Catch-Up audit for network drops or skipped SMS
  Timer.periodic(const Duration(minutes: 15), (timer) async {
    dev.log('Running periodic 15-min SMS inbox audit...',
        name: 'BirrSync.Service');
    await CatchUpWorker.scanInboxForMissedReceipts();
  });

  // Periodic 5-minute heartbeat ping to Go server
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    dev.log('Sending 5-min heartbeat ping...', name: 'BirrSync.Service');
    await SyncService.sendHeartbeat();
  });
}
