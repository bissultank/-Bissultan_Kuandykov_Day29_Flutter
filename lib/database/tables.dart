// lib/database/tables.dart
import 'package:drift/drift.dart';

// Таблица тегов
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get color => text().withLength(min: 6, max: 7).withDefault(const Constant('FF5722'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Таблица задач
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get priority => integer().withDefault(const Constant(1))();
  
  // Foreign Key - связь с таблицей Tags
  IntColumn get tagId => integer().nullable()
    .references(Tags, #id, onDelete: KeyAction.setNull)();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  List<String> get customConstraints => const [
    'CHECK (priority BETWEEN 1 AND 5)',
  ];
}
