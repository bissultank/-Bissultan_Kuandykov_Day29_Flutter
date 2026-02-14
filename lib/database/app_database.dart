// lib/database/app_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Tasks, Tags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ==================== CRUD для Tags ====================
  
  Future<int> createTag(String name, String color) {
    return into(tags).insert(
      TagsCompanion.insert(name: name, color: Value(color)),
    );
  }
  
  Stream<List<Tag>> watchAllTags() {
    return select(tags).watch();
  }

  Future<List<Tag>> getAllTagsOnce() {
    return (select(tags)
      ..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }
  
  Future<bool> updateTag(Tag tag) {
    return update(tags).replace(tag);
  }
  
  Future<int> deleteTag(int id) {
    return (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  // ==================== CRUD для Tasks ====================
  
  Future<int> createTask({
    required String title,
    String? description,
    int priority = 1,
    int? tagId,
  }) {
    return into(tasks).insert(
      TasksCompanion.insert(
        title: title,
        description: Value(description),
        priority: Value(priority),
        tagId: Value(tagId),
      ),
    );
  }
  
  // ✅ WATCH - Stream с автоматическим обновлением
  Stream<List<Task>> watchAllTasks() {
    return select(tasks).watch();
  }
  
  // ❌ GET - Одноразовый запрос (нужно обновлять вручную)
  Future<List<Task>> getAllTasksOnce() {
    return select(tasks).get();
  }
  
  // Сортировка по дате (новые первые)
  Stream<List<Task>> watchTasksSortedByDate() {
    return (select(tasks)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
      ]))
        .watch();
  }
  
  // Сортировка по приоритету (высокий первым)
  Stream<List<Task>> watchTasksSortedByPriority() {
    return (select(tasks)
      ..orderBy([
        (t) => OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]))
        .watch();
  }
  
  Future<bool> updateTask(Task task) {
    return update(tasks).replace(
      task.copyWith(updatedAt: Value(DateTime.now())),
    );
  }
  
  Future<bool> toggleTaskCompleted(Task task) {
    return update(tasks).replace(
      task.copyWith(
        isCompleted: !task.isCompleted,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
  
  Future<int> deleteTask(int id) {
    return (delete(tasks)..where((t) => t.id.equals(id))).go();
  }

  // ==================== JOIN запросы ====================
  
  Stream<List<TaskWithTag>> watchTasksWithTags() {
    final query = select(tasks).join([
      leftOuterJoin(tags, tags.id.equalsExp(tasks.tagId)),
    ]);
    
    return query.watch().map((rows) {
      return rows.map((row) {
        return TaskWithTag(
          task: row.readTable(tasks),
          tag: row.readTableOrNull(tags),
        );
      }).toList();
    });
  }
}

class TaskWithTag {
  final Task task;
  final Tag? tag;
  TaskWithTag({required this.task, this.tag});
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'tasks_db.sqlite'));
    return NativeDatabase(file);
  });
}
