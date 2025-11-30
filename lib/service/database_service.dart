import 'dart:io';
import 'package:flutter/foundation.dart'; // Needed for kIsWeb and defaultTargetPlatform
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NEW

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // --- Common Constants ---
  static const String _chatIdKey = 'chatId';

  // Determine if we should use SharedPreferences (for desktop/web)
  bool get _useSharedPreferences {
    // Check for Windows, Linux, macOS, or Web platforms
    if (kIsWeb) return true;
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return true;
    }
    return false;
  }

  // --- SQFLITE Properties (Mobile Only) ---
  static Database? _database;
  static const String _tableName = 'settings';
  static const int _version = 1;

  // --- SQFLITE Initialization (Mobile Only) ---
  Future<Database> get _sqfliteDatabase async {
    if (_database != null) return _database!;
    _database = await _initSqfliteDb();
    return _database!;
  }

  Future<Database> _initSqfliteDb() async {
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

  // -------------------------------------------------------------------
  // --- Public Interface: Save Chat ID (Cross-Platform Implementation) ---
  // -------------------------------------------------------------------

  Future<void> saveChatId(String chatId) async {
    if (_useSharedPreferences) {
      // ⭐️ WINDOWS/DESKTOP/WEB LOGIC
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatIdKey, chatId);
    } else {
      // 📱 MOBILE (ANDROID/IOS) LOGIC: Keep your existing SQFLITE code
      final db = await _sqfliteDatabase;
      await db.insert(
        _tableName,
        {'key': _chatIdKey, 'value': chatId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // -------------------------------------------------------------------
  // --- Public Interface: Retrieve Chat ID (Cross-Platform Implementation) ---
  // -------------------------------------------------------------------

  Future<String?> getChatId() async {
    if (_useSharedPreferences) {
      // ⭐️ WINDOWS/DESKTOP/WEB LOGIC
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_chatIdKey);
    } else {
      // 📱 MOBILE (ANDROID/IOS) LOGIC: Keep your existing SQFLITE code
      final db = await _sqfliteDatabase;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'key = ?',
        whereArgs: [_chatIdKey],
      );

      if (maps.isNotEmpty) {
        return maps.first['value'] as String;
      }
      return null;
    }
  }
}