import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sub3/app/models/sub.dart';
import 'package:sub3/app/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('DatabaseService initializes and operates on Linux', () async {
    // We can test DatabaseService methods
    final dbService = DatabaseService.instance;
    final sub = Sub('Test Sub', File('/tmp/test.srt'), File('/tmp/test.mp3'));
    final id = await dbService.saveSub(sub);
    expect(id, isPositive);

    final allSubs = await dbService.getAllSubs();
    expect(allSubs.any((s) => s.name == 'Test Sub'), isTrue);

    await dbService.deleteSub(id);
    await dbService.close();
  });
}
