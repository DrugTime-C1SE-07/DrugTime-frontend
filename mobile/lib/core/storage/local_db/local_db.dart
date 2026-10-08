import 'package:path/path.dart' as path;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../secure_storage.dart';

class LocalDb {
  LocalDb(this._secureStorage);

  static const schedulesTable = 'local_medication_schedules';
  static const doseLogsTable = 'local_dose_logs';
  static const syncMetaTable = 'local_sync_meta';

  final SecureStorage _secureStorage;

  Database? _database;

  Future<Database> get database async {
    final currentDatabase = _database;
    if (currentDatabase != null) {
      return currentDatabase;
    }

    final dbPassword = await _secureStorage.getOrCreateDatabasePassword();
    final dbPath = await _databasePath();

    _database = await openDatabase(
      dbPath,
      password: dbPassword,
      version: 1,
      onCreate: createSchema,
    );

    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<String> _databasePath() async {
    final basePath = await getDatabasesPath();
    return path.join(basePath, 'drugtime_local_store.db');
  }

  static Future<void> createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $schedulesTable (
        id INTEGER PRIMARY KEY,
        patient_user_id TEXT NOT NULL,
        user_medication_id INTEGER NOT NULL,
        medication_id INTEGER NOT NULL,
        medication_name TEXT NOT NULL,
        strength_text TEXT,
        dosage_form TEXT,
        quantity_per_dose TEXT NOT NULL,
        doses_per_day INTEGER NOT NULL,
        intake_time TEXT NOT NULL,
        days_of_week TEXT NOT NULL,
        reminder_enabled INTEGER NOT NULL,
        effective_from TEXT NOT NULL,
        ended_at TEXT,
        server_synced_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_${schedulesTable}_active
      ON $schedulesTable (patient_user_id, reminder_enabled, ended_at, intake_time)
    ''');

    await db.execute('''
      CREATE TABLE $doseLogsTable (
        client_uuid TEXT PRIMARY KEY,
        id INTEGER,
        medication_schedule_id INTEGER NOT NULL,
        scheduled_at TEXT NOT NULL,
        taken_at TEXT,
        status TEXT NOT NULL,
        sync_state TEXT NOT NULL,
        synced_at TEXT,
        last_error TEXT,
        local_updated_at TEXT NOT NULL,
        UNIQUE (medication_schedule_id, scheduled_at)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_${doseLogsTable}_pending
      ON $doseLogsTable (sync_state, scheduled_at)
    ''');

    await db.execute('''
      CREATE TABLE $syncMetaTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }
}
