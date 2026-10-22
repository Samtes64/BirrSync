import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../parser/telebirr_parser.dart';

class QueueItem {
  final int? id;
  final String transactionId;
  final String provider;
  final double amount;
  final String? senderName;
  final String? maskedPhone;
  final String? phoneSuffix;
  final String raw;
  final int timestamp;
  final String syncStatus; // 'PENDING', 'SYNCED', 'FAILED'
  final int retryCount;
  final String? errorMessage;
  final int createdAt;
  final int? syncedAt;

  QueueItem({
    this.id,
    required this.transactionId,
    required this.provider,
    required this.amount,
    this.senderName,
    this.maskedPhone,
    this.phoneSuffix,
    required this.raw,
    required this.timestamp,
    this.syncStatus = 'PENDING',
    this.retryCount = 0,
    this.errorMessage,
    required this.createdAt,
    this.syncedAt,
  });

  factory QueueItem.fromMap(Map<String, dynamic> map) {
    return QueueItem(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as String,
      provider: map['provider'] as String,
      amount: (map['amount'] as num).toDouble(),
      senderName: map['sender_name'] as String?,
      maskedPhone: map['masked_phone'] as String?,
      phoneSuffix: map['phone_suffix'] as String?,
      raw: map['raw'] as String,
      timestamp: map['timestamp'] as int,
      syncStatus: map['sync_status'] as String? ?? 'PENDING',
      retryCount: map['retry_count'] as int? ?? 0,
      errorMessage: map['error_message'] as String?,
      createdAt: map['created_at'] as int,
      syncedAt: map['synced_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'transaction_id': transactionId,
      'provider': provider,
      'amount': amount,
      'sender_name': senderName,
      'masked_phone': maskedPhone,
      'phone_suffix': phoneSuffix,
      'raw': raw,
      'timestamp': timestamp,
      'sync_status': syncStatus,
      'retry_count': retryCount,
      'error_message': errorMessage,
      'created_at': createdAt,
      'synced_at': syncedAt,
    };
  }

  Map<String, dynamic> toApiJson() {
    return {
      'provider': provider,
      'transaction_id': transactionId,
      'amount': amount,
      'sender_name': senderName ?? '',
      'masked_phone': maskedPhone ?? '',
      'phone_suffix': phoneSuffix ?? '',
      'raw': raw,
      'device_time': timestamp,
    };
  }
}

class QueueDatabase {
  static final QueueDatabase instance = QueueDatabase._init();
  static Database? _database;

  QueueDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('birrsync_queue.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE queue_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT UNIQUE NOT NULL,
        provider TEXT NOT NULL,
        amount REAL NOT NULL,
        sender_name TEXT,
        masked_phone TEXT,
        phone_suffix TEXT,
        raw TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        retry_count INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        created_at INTEGER NOT NULL,
        synced_at INTEGER
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_queue_status ON queue_transactions(sync_status);');
    await db.execute(
        'CREATE INDEX idx_queue_txn ON queue_transactions(transaction_id);');
  }

  /// Inserts a parsed receipt into local queue (ignores duplicates)
  Future<bool> insertTransaction(ParsedReceipt receipt) async {
    final db = await database;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final row = {
        'transaction_id': receipt.transactionId,
        'provider': receipt.provider,
        'amount': receipt.amount,
        'sender_name': receipt.senderName,
        'masked_phone': receipt.maskedPhone,
        'phone_suffix': receipt.phoneSuffix,
        'raw': receipt.raw,
        'timestamp': receipt.timestamp,
        'sync_status': 'PENDING',
        'retry_count': 0,
        'created_at': now,
      };

      final id = await db.insert(
        'queue_transactions',
        row,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return id > 0;
    } catch (_) {
      return false;
    }
  }

  /// Checks if a transaction ID has already been recorded
  Future<bool> exists(String transactionId) async {
    final db = await database;
    final res = await db.query(
      'queue_transactions',
      columns: ['id'],
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  /// Fetches pending transactions to be synced with Go server
  Future<List<QueueItem>> getPendingTransactions({int limit = 50}) async {
    final db = await database;
    final res = await db.query(
      'queue_transactions',
      where: "sync_status = 'PENDING'",
      orderBy: 'id ASC',
      limit: limit,
    );
    return res.map((m) => QueueItem.fromMap(m)).toList();
  }

  /// Marks transaction as SYNCED
  Future<void> markAsSynced(String transactionId) async {
    final db = await database;
    await db.update(
      'queue_transactions',
      {
        'sync_status': 'SYNCED',
        'synced_at': DateTime.now().millisecondsSinceEpoch,
        'error_message': null,
      },
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  /// Records failed sync attempt and increments retry count
  Future<void> markAsFailed(String transactionId, String error) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE queue_transactions 
      SET retry_count = retry_count + 1, error_message = ? 
      WHERE transaction_id = ?
      ''',
      [error, transactionId],
    );
  }

  /// Returns recent transactions for the status UI
  Future<List<QueueItem>> getRecentTransactions({int limit = 100}) async {
    final db = await database;
    final res = await db.query(
      'queue_transactions',
      orderBy: 'id DESC',
      limit: limit,
    );
    return res.map((m) => QueueItem.fromMap(m)).toList();
  }

  /// Retrieves summary statistics for the UI cards
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;
    final totalCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM queue_transactions'),
        ) ??
        0;

    final pendingCount = Sqflite.firstIntValue(
          await db.rawQuery(
              "SELECT COUNT(*) FROM queue_transactions WHERE sync_status = 'PENDING'"),
        ) ??
        0;

    final syncedCount = Sqflite.firstIntValue(
          await db.rawQuery(
              "SELECT COUNT(*) FROM queue_transactions WHERE sync_status = 'SYNCED'"),
        ) ??
        0;

    final totalVolumeRes = await db.rawQuery(
        "SELECT SUM(amount) as total FROM queue_transactions WHERE sync_status = 'SYNCED'");
    final totalVolume = (totalVolumeRes.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'total': totalCount,
      'pending': pendingCount,
      'synced': syncedCount,
      'volume': totalVolume,
    };
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
