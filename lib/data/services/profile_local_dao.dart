import 'package:sqflite/sqflite.dart';

import '../../domain/models/profile.dart';
import 'local_db.dart';

/// CRUD de la tabla `profile` en SQLite.
class ProfileLocalDao {
  const ProfileLocalDao();

  Future<Profile?> find(String userId) async {
    final rows = await LocalDb.instance.db.query(
      'profile',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Profile.fromDbMap(rows.first);
  }

  Future<Profile?> findAny() async {
    final rows = await LocalDb.instance.db.query(
      'profile',
      orderBy: 'synced_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Profile.fromDbMap(rows.first);
  }

  Future<void> upsert(Profile profile) async {
    await LocalDb.instance.db.insert(
      'profile',
      profile.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String userId) async {
    await LocalDb.instance.db.delete(
      'profile',
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> clear() async {
    await LocalDb.instance.db.delete('profile');
  }
}
