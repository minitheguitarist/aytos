import 'package:aytos/main.dart';
import 'package:aytos/store.dart';
import 'package:aytos/user_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

class UnusedDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class DemoStore extends Store {
  DemoStore() : super(UnusedDatabase());
  @override
  Future<List<DbRow>> containers() async => [];
  @override
  Future<List<DbRow>> deliveries({int? userId}) async => [];
  @override
  Future<List<DbRow>> ranking() async => [
    {'id': 2, 'name': 'Test Kullanıcı', 'points': 0},
  ];
  @override
  Future<List<DbRow>> ledger(int userId) async => [];
}

void main() {
  testWidgets(
    'login fits a small Android screen with registration and admin entry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(AytosApp(store: DemoStore()));
      expect(find.text('Giriş yap'), findsOneWidget);
      expect(find.text('Demo admin girişi'), findsOneWidget);
      await tester.tap(find.text('Hesap oluştur'));
      await tester.pump();
      expect(find.text('Kayıt ol'), findsOneWidget);
      expect(find.text('Ad soyad'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('quantity, walking and car controls fit a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: UserHome(
          store: DemoStore(),
          user: const {'id': 2, 'name': 'Test Kullanıcı', 'role': 'user'},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Yürüyerek'), findsOneWidget);
    expect(find.text('Araçla'), findsOneWidget);
    expect(find.text('Uygun konteynırı bul'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
