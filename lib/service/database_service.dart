import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static const String _tableName = 'settings';
  static const String _keyChatId = 'chatId';
  static const int _version = 1;

  // --- Initialize Database ---
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'video_downloader.db');
    return await openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName(
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
  }

  // --- Save Chat ID ---
  Future<void> saveChatId(String chatId) async {
    final db = await database;
    await db.insert(
      _tableName,
      {'key': _keyChatId, 'value': chatId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Retrieve Chat ID ---
  Future<String?> getChatId() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'key = ?',
      whereArgs: [_keyChatId],
    );

    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }
}