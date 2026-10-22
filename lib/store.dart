import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

typedef DbRow = Map<String, Object?>;

class Store {
  final Database db;
  Store(this.db);
  static Future<Store> open({
    DatabaseFactory? factory,
    String? databasePath,
  }) async {
    final f = factory ?? databaseFactory;
    final location =
        databasePath ?? path.join(await f.getDatabasesPath(), 'aytos.db');
    final db = await f.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE NOT NULL, password TEXT NOT NULL, role TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE containers(id INTEGER PRIMARY KEY, name TEXT NOT NULL, neighborhood TEXT NOT NULL, street TEXT NOT NULL, lat REAL NOT NULL, lon REAL NOT NULL, capacity REAL NOT NULL, fill REAL NOT NULL, active INTEGER NOT NULL DEFAULT 1)',
          );
          await db.execute(
            "CREATE TABLE deliveries(id TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), container_id INTEGER NOT NULL REFERENCES containers(id), liters REAL NOT NULL, base_points INTEGER NOT NULL, created TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', reviewed TEXT, container_name TEXT NOT NULL, address TEXT NOT NULL)",
          );
          await db.execute(
            'CREATE TABLE ledger(id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), delivery_id TEXT NOT NULL REFERENCES deliveries(id), kind TEXT NOT NULL, points INTEGER NOT NULL, created TEXT NOT NULL, UNIQUE(delivery_id, kind))',
          );
          await db.execute(
            'CREATE TABLE decisions(id INTEGER PRIMARY KEY, delivery_id TEXT UNIQUE NOT NULL REFERENCES deliveries(id), container_id INTEGER NOT NULL REFERENCES containers(id), command TEXT NOT NULL, state TEXT NOT NULL, created TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE settings(id INTEGER PRIMARY KEY CHECK(id = 1), bonus INTEGER NOT NULL, penalty INTEGER NOT NULL)',
          );
          await db.insert('settings', {'id': 1, 'bonus': 5, 'penalty': 200});
          await db.insert('users', {
            'name': 'Demo Admin',
            'email': 'admin@aytos.local',
            'password': await hashPassword('Aytos123!'),
            'role': 'admin',
          });
          // These are demo locations, not deployed collection points.
          for (final c in [
            {
              'name': 'Konteynır A',
              'neighborhood': 'Medrese',
              'street': 'Demo nokta 1',
              'lat': 39.8180,
              'lon': 34.8147,
              'capacity': 100.0,
              'fill': 20.0,
            },
            {
              'name': 'Konteynır B',
              'neighborhood': 'Aşağı Nohutlu',
              'street': 'Demo nokta 2',
              'lat': 39.8222,
              'lon': 34.8087,
              'capacity': 100.0,
              'fill': 65.0,
            },
            {
              'name': 'Konteynır C',
              'neighborhood': 'Yukarı Nohutlu',
              'street': 'Demo nokta 3',
              'lat': 39.8240,
              'lon': 34.8202,
              'capacity': 100.0,
              'fill': 95.0,
            },
          ]) {
            await db.insert('containers', c);
          }
        },
      ),
    );
    return Store(db);
  }

  static Future<String> hashPassword(String password, {List<int>? salt}) async {
    final s = salt ?? List.generate(16, (_) => Random.secure().nextInt(256));
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 120000,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: s);
    return '${base64Encode(s)}:${base64Encode(await key.extractBytes())}';
  }

  Future<DbRow> register(String name, String email, String password) async {
    name = name.trim();
    email = email.trim().toLowerCase();
    if (name.length < 2 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        password.length < 8) {
      throw Exception(
        'Ad en az 2, parola en az 8 karakter olmalı; geçerli bir e-posta girin.',
      );
    }
    if ((await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    )).isNotEmpty) {
      throw Exception('Bu e-posta zaten kayıtlı.');
    }
    final id = await db.insert('users', {
      'name': name,
      'email': email,
      'password': await hashPassword(password),
      'role': 'user',
    });
    return (await db.query('users', where: 'id = ?', whereArgs: [id])).single;
  }

  Future<DbRow> login(String email, String password) async {
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
    if (rows.isNotEmpty) {
      final stored = rows.single['password'] as String;
      final candidate = await hashPassword(
        password,
        salt: base64Decode(stored.split(':').first),
      );
      var difference = 0;
      for (var i = 0; i < stored.length; i++) {
        difference |= stored.codeUnitAt(i) ^ candidate.codeUnitAt(i);
      }
      if (difference == 0) {
        return rows.single;
      }
    }
    throw Exception('E-posta veya parola hatalı.');
  }

  Future<List<DbRow>> containers() => db.query('containers', orderBy: 'name');
  Future<List<DbRow>> deliveries({int? userId}) => db.rawQuery(
    '''SELECT d.*, u.name AS user_name FROM deliveries d JOIN users u ON u.id = d.user_id ${userId == null ? '' : 'WHERE d.user_id = ?'} ORDER BY d.created DESC''',
    userId == null ? [] : [userId],
  );
  Future<List<DbRow>> ranking() => db.rawQuery(
    "SELECT u.id, u.name, COALESCE(SUM(l.points),0) AS points FROM users u LEFT JOIN ledger l ON l.user_id = u.id WHERE u.role = 'user' GROUP BY u.id ORDER BY points DESC, u.name",
  );
  Future<List<DbRow>> ledger(int userId) => db.query(
    'ledger',
    where: 'user_id = ?',
    whereArgs: [userId],
    orderBy: 'id DESC',
  );
  Future<DbRow> settings() async => (await db.query('settings')).single;
  Future<void> saveSettings(int bonus, int penalty) async {
    if (bonus < 0 || penalty < 0) {
      throw Exception('Puan değerleri negatif olamaz.');
    }
    await db.update('settings', {
      'bonus': bonus,
      'penalty': penalty,
    }, where: 'id = 1');
  }

  Future<void> saveContainer(DbRow row) async {
    if ((row['capacity'] as num) <= 0 ||
        (row['fill'] as num) < 0 ||
        (row['fill'] as num) > (row['capacity'] as num)) {
      throw Exception('Doluluk 0 ile kapasite arasında olmalı.');
    }
    if (row['id'] == null) {
      await db.insert('containers', row);
    } else {
      await db.update(
        'containers',
        row,
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  // Confirmation and points are committed together. The session ID is idempotent.
  Future<void> confirm(
    String sessionId,
    int userId,
    int containerId,
    double liters,
  ) async {
    if (liters <= 0 || !liters.isFinite) {
      throw Exception('Geçersiz miktar.');
    }
    await db.transaction((tx) async {
      if ((await tx.query(
        'deliveries',
        where: 'id = ?',
        whereArgs: [sessionId],
      )).isNotEmpty) {
        return;
      }
      final c = (await tx.query(
        'containers',
        where: 'id = ?',
        whereArgs: [containerId],
      )).single;
      if (c['active'] != 1 ||
          (c['capacity'] as num) - (c['fill'] as num) < liters) {
        throw Exception(
          'Konteynır artık uygun değil. Lütfen yeniden rota seçin.',
        );
      }
      final user = (await tx.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      )).single;
      if (user['role'] != 'user') {
        throw Exception('Teslim için kullanıcı hesabı gerekir.');
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final points = (liters * 10).round();
      await tx.insert('deliveries', {
        'id': sessionId,
        'user_id': userId,
        'container_id': containerId,
        'liters': liters,
        'base_points': points,
        'created': now,
        'container_name': c['name'],
        'address': '${c['neighborhood']} Mahallesi · ${c['street']}',
      });
      await tx.insert('ledger', {
        'user_id': userId,
        'delivery_id': sessionId,
        'kind': 'base',
        'points': points,
        'created': now,
      });
      await tx.update(
        'containers',
        {'fill': (c['fill'] as num).toDouble() + liters},
        where: 'id = ?',
        whereArgs: [containerId],
      );
    });
  }

  Future<void> review(int adminId, String deliveryId, bool oil) async {
    await db.transaction((tx) async {
      final admin = (await tx.query(
        'users',
        where: 'id = ?',
        whereArgs: [adminId],
      )).single;
      if (admin['role'] != 'admin') {
        throw Exception('Admin yetkisi gerekli.');
      }
      final d = (await tx.query(
        'deliveries',
        where: 'id = ?',
        whereArgs: [deliveryId],
      )).single;
      if (d['status'] != 'pending') {
        return;
      }
      final s = (await tx.query('settings')).single;
      final now = DateTime.now().toUtc().toIso8601String();
      await tx.update(
        'deliveries',
        {'status': oil ? 'accepted' : 'rejected', 'reviewed': now},
        where: 'id = ?',
        whereArgs: [deliveryId],
      );
      if (!oil) {
        await tx.insert('ledger', {
          'user_id': d['user_id'],
          'delivery_id': deliveryId,
          'kind': 'reversal',
          'points': -(d['base_points'] as int),
          'created': now,
        });
      }
      await tx.insert('ledger', {
        'user_id': d['user_id'],
        'delivery_id': deliveryId,
        'kind': oil ? 'bonus' : 'penalty',
        'points': oil ? s['bonus'] : -(s['penalty'] as int),
        'created': now,
      });
      await tx.insert('decisions', {
        'delivery_id': deliveryId,
        'container_id': d['container_id'],
        'command': oil ? 'ACCEPT' : 'REJECT',
        'state': 'simulated',
        'created': now,
      });
    });
  }
}
