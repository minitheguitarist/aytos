import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aytos/store.dart';

void main() {
  sqfliteFfiInit();
  late Store store;
  late Directory directory;
  late DbRow user, admin;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('aytos-test-');
    store = await Store.open(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/test.db',
    );
    user = await store.register(
      'Test Kullanıcı',
      'user@example.com',
      'Password123',
    );
    admin = await store.login('admin@aytos.local', 'Aytos123!');
  });
  tearDown(() async {
    await store.db.close();
    await directory.delete(recursive: true);
  });
  Future<int> points() async => (await store.ranking()).single['points'] as int;
  test(
    'QR confirmation only grants base points once; oil review only grants one bonus',
    () async {
      final c = (await store.containers()).first;
      await Future.wait(
        List.generate(
          3,
          (_) =>
              store.confirm('delivery-1', user['id'] as int, c['id'] as int, 2),
        ),
      );
      expect(await points(), 20);
      expect((await store.deliveries()).length, 1);
      expect((await store.containers()).first['fill'], 22);
      await Future.wait(
        List.generate(
          3,
          (_) => store.review(admin['id'] as int, 'delivery-1', true),
        ),
      );
      expect(await points(), 25);
      await store.review(admin['id'] as int, 'delivery-1', false);
      expect(await points(), 25);
      expect((await store.db.query('decisions')).single['command'], 'ACCEPT');
    },
  );
  test('non-oil reverses base points and applies minus 200 once', () async {
    await store.confirm('delivery-2', user['id'] as int, 1, 0.5);
    expect(await points(), 5);
    await store.review(admin['id'] as int, 'delivery-2', false);
    await store.review(admin['id'] as int, 'delivery-2', false);
    expect(await points(), -200);
    expect(
      (await store.ledger(user['id'] as int)).map((l) => l['points']).toList(),
      [-200, -5, 5],
    );
    expect((await store.db.query('decisions')).single['state'], 'simulated');
  });
  test(
    'capacity failure has no partial delivery or points; user cannot review',
    () async {
      await expectLater(
        store.confirm('too-large', user['id'] as int, 3, 6),
        throwsException,
      );
      expect(await store.deliveries(), isEmpty);
      expect(await points(), 0);
      await store.confirm('normal', user['id'] as int, 1, 1);
      await expectLater(
        store.review(user['id'] as int, 'normal', false),
        throwsException,
      );
      expect(await points(), 10);
    },
  );
  test('accounts, points and decisions survive database reopen', () async {
    await store.confirm('persistent', user['id'] as int, 1, 1);
    await store.review(admin['id'] as int, 'persistent', true);
    await store.db.close();
    store = await Store.open(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/test.db',
    );
    expect(
      (await store.login('USER@example.com', 'Password123'))['id'],
      user['id'],
    );
    expect(await points(), 15);
    expect((await store.deliveries()).single['status'], 'accepted');
    expect(
      (await store.db.query('users')).first['password'],
      isNot('Aytos123!'),
    );
  });
  test('wrong password and duplicate normalized email are rejected', () async {
    await expectLater(
      store.login('user@example.com', 'wrongpassword'),
      throwsException,
    );
    await expectLater(
      store.register('Başka Kullanıcı', 'USER@example.com', 'Password123'),
      throwsException,
    );
    expect((await store.db.query('users')).length, 2);
  });
}
