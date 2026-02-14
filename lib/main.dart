// lib/main.dart
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'database/app_database.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bissultan Kuandykov - Day 29',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const TasksScreen(),
    );
  }
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  final database = AppDatabase();
  late TabController _tabController;

  // Для сравнения: список для GET (ручное обновление)
  List<Task> _manualTasks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadManualTasks();
  }

  Future<void> _loadManualTasks() async {
    setState(() => _isLoading = true);
    final tasks = await database.getAllTasksOnce();
    if (!mounted) return;
    setState(() {
      _manualTasks = tasks;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    database.close();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Локальная база данных'),
        actions: [
          IconButton(
            onPressed: _showManageTagsDialog,
            icon: const Icon(Icons.label),
            tooltip: 'Управление тегами',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.stream), text: 'Stream (Auto)'),
            Tab(icon: Icon(Icons.refresh), text: 'Get (Manual)'),
            Tab(icon: Icon(Icons.sort), text: 'Сортировка'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStreamTab(),
          _buildGetTab(),
          _buildSortingTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  // TAB 1: Stream - АВТОМАТИЧЕСКОЕ обновление
  Widget _buildStreamTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green.shade50,
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '✅ Stream автоматически обновляет UI при любых изменениях',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<TaskWithTag>>(
            stream: database.watchTasksWithTags(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Center(child: Text('Нет задач. Добавьте первую!'));
              }

              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildTaskCard(item.task, item.tag);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // TAB 2: Get - РУЧНОЕ обновление
  Widget _buildGetTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.orange.shade50,
          child: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '⚠️ Get требует ручного обновления. Нажмите 🔄',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadManualTasks,
                tooltip: 'Обновить вручную',
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _manualTasks.isEmpty
                  ? const Center(
                      child: Text('Нет задач. Нажмите 🔄 после добавления'))
                  : ListView.builder(
                      itemCount: _manualTasks.length,
                      itemBuilder: (context, index) {
                        return _buildTaskCard(_manualTasks[index], null);
                      },
                    ),
        ),
      ],
    );
  }

  // TAB 3: Сортировка
  Widget _buildSortingTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.blue.shade50,
            child: const TabBar(
              labelColor: Colors.blue,
              tabs: [
                Tab(text: 'По дате ↓'),
                Tab(text: 'По приоритету ↓'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // По дате
                StreamBuilder<List<Task>>(
                  stream: database.watchTasksSortedByDate(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, i) =>
                          _buildTaskCard(snapshot.data![i], null),
                    );
                  },
                ),
                // По приоритету
                StreamBuilder<List<Task>>(
                  stream: database.watchTasksSortedByPriority(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, i) =>
                          _buildTaskCard(snapshot.data![i], null),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task, Tag? tag) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (_) => database.toggleTaskCompleted(task),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(
          children: [
            Chip(
              label: Text('P${task.priority}'),
              backgroundColor: _getPriorityColor(task.priority),
              labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
              padding: EdgeInsets.zero,
            ),
            if (tag != null) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text(tag.name),
                backgroundColor: Color(int.parse('FF${tag.color}', radix: 16))
                    .withValues(alpha: 0.3),
                labelStyle: const TextStyle(fontSize: 12),
                padding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showEditDialog(task),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: () => database.deleteTask(task.id),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    final safePriority = priority.clamp(1, 5).toInt();
    return [
      Colors.grey,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple
    ][safePriority];
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final tagsFuture = database.getAllTagsOnce();
    int priority = 1;
    int? selectedTagId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Новая задача'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Название'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Приоритет: '),
                  DropdownButton<int>(
                    value: priority,
                    items: List.generate(5, (i) => i + 1)
                        .map((p) =>
                            DropdownMenuItem(value: p, child: Text('P$p')))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => priority = value!),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Tag>>(
                future: tagsFuture,
                builder: (context, snapshot) {
                  final allTags = snapshot.data ?? const <Tag>[];
                  return DropdownButtonFormField<int?>(
                    initialValue: selectedTagId,
                    decoration: const InputDecoration(labelText: 'Тег'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Без тега'),
                      ),
                      ...allTags.map(
                        (tag) => DropdownMenuItem<int?>(
                          value: tag.id,
                          child: Text(tag.name),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => selectedTagId = value),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  await database.createTask(
                    title: titleController.text,
                    priority: priority,
                    tagId: selectedTagId,
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Task task) {
    final titleController = TextEditingController(text: task.title);
    final tagsFuture = database.getAllTagsOnce();
    int priority = task.priority;
    int? selectedTagId = task.tagId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Редактировать'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Приоритет: '),
                  DropdownButton<int>(
                    value: priority,
                    items: List.generate(5, (i) => i + 1)
                        .map((p) =>
                            DropdownMenuItem(value: p, child: Text('P$p')))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => priority = value!),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Tag>>(
                future: tagsFuture,
                builder: (context, snapshot) {
                  final allTags = snapshot.data ?? const <Tag>[];
                  return DropdownButtonFormField<int?>(
                    initialValue: selectedTagId,
                    decoration: const InputDecoration(labelText: 'Тег'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Без тега'),
                      ),
                      ...allTags.map(
                        (tag) => DropdownMenuItem<int?>(
                          value: tag.id,
                          child: Text(tag.name),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => selectedTagId = value),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  await database.updateTask(
                    task.copyWith(
                      title: titleController.text,
                      priority: priority,
                      tagId: Value(selectedTagId),
                    ),
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageTagsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Теги'),
        content: SizedBox(
          width: 360,
          child: StreamBuilder<List<Tag>>(
            stream: database.watchAllTags(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final tags = snapshot.data!;
              if (tags.isEmpty) {
                return const SizedBox(
                  height: 160,
                  child: Center(child: Text('Нет тегов. Добавьте первый.')),
                );
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Color(int.parse(
                            'FF${_normalizeHexColor(tag.color)}',
                            radix: 16)),
                        radius: 10,
                      ),
                      title: Text(tag.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () =>
                                _showTagEditorDialog(existing: tag),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => database.deleteTag(tag.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: _showTagEditorDialog,
            child: const Text('Добавить тег'),
          ),
        ],
      ),
    );
  }

  void _showTagEditorDialog({Tag? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final colorController =
        TextEditingController(text: existing?.color ?? 'FF5722');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Новый тег' : 'Редактировать тег'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: colorController,
              decoration: const InputDecoration(
                labelText: 'Цвет (HEX)',
                hintText: 'FF5722 или #FF5722',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final color = _normalizeHexColor(colorController.text);
              if (name.isEmpty) return;

              if (existing == null) {
                await database.createTag(name, color);
              } else {
                await database.updateTag(
                  existing.copyWith(name: name, color: color),
                );
              }

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  String _normalizeHexColor(String input) {
    final cleaned = input.trim().replaceFirst('#', '').toUpperCase();
    if (RegExp(r'^[0-9A-F]{6}$').hasMatch(cleaned)) return cleaned;
    return 'FF5722';
  }
}
