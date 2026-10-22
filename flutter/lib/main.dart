import 'package:flutter/material.dart';
import 'database/queue_db.dart';
import 'services/background_service.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite offline queue database
  try {
    await QueueDatabase.instance.database;
  } catch (e) {
    debugPrint('Queue DB init error: $e');
  }

  // Launch UI immediately so Android shows the activity window without delay
  runApp(const BirrSyncAgentApp());

  // Configure background service asynchronously without blocking startup
  Future.microtask(() async {
    await initializeBackgroundService();
  });
}

class BirrSyncAgentApp extends StatelessWidget {
  const BirrSyncAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0D5C3A);

    return MaterialApp(
      title: 'BirrSync Gateway',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          primary: primaryGreen,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
