import 'database.dart';

/// AppDatabase class
/// Database instance is registered via GetX in InitialBinding
class AppDatabaseProvider {
  static AppDatabase? _instance;

  static AppDatabase get instance {
    _instance ??= AppDatabase();
    return _instance!;
  }
}
