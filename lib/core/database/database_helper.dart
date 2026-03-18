import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'models/mistake.dart';

class DatabaseHelper {
  // Singleton 模式
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'mistakes.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE mistakes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        title TEXT NOT NULL,
        tags TEXT NOT NULL,
        solutions TEXT NOT NULL,
        subject TEXT NOT NULL,
        category TEXT NOT NULL,
        error_reason TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  // CREATE: 新增錯題
  Future<int> insertMistake(Mistake mistake) async {
    final db = await database;
    return await db.insert('mistakes', mistake.toMap());
  }

  // READ: 讀取全部錯題
  Future<List<Mistake>> getAllMistakes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'mistakes',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Mistake.fromMap(maps[i]));
  }

  // READ: 依 id 讀取單一錯題
  Future<Mistake?> getMistakeById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'mistakes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Mistake.fromMap(maps.first);
  }

  // UPDATE: 更新錯題
  Future<int> updateMistake(Mistake mistake) async {
    final db = await database;
    return await db.update(
      'mistakes',
      mistake.toMap(),
      where: 'id = ?',
      whereArgs: [mistake.id],
    );
  }

  // DELETE: 刪除錯題
  Future<int> deleteMistake(int id) async {
    final db = await database;
    return await db.delete(
      'mistakes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 關閉資料庫（通常在 App 關閉時呼叫）
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

