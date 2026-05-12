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

  Future<void> upsert(Profile profile, {bool pendingUpdate = false}) async {
    final map = profile.toDbMap();
    map['pending_update'] = pendingUpdate ? 1 : 0;
    await LocalDb.instance.db.insert(
      'profile',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Profile?> findPendingUpdate() async {
    final rows = await LocalDb.instance.db.query(
      'profile',
      where: 'pending_update = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Profile.fromDbMap(rows.first);
  }

  Future<void> clearPendingFlag(String id) async {
    await LocalDb.instance.db.update(
      'profile',
      {'pending_update': 0},
      where: 'id = ?',
      whereArgs: [id],
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
