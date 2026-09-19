import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

// --- Модель данных задачи ---
enum Priority { low, medium, high }

class Task {
  String id;
  String title;
  String description;
  bool isCompleted;
  Priority priority;
  DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    this.priority = Priority.medium,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Преобразование в Map для сохранения
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'isCompleted': isCompleted,
        'priority': priority.index,
        'createdAt': createdAt.toIso8601String(),
      };

  // Восстановление из Map
  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        description: json['description'] ?? '',
        isCompleted: json['isCompleted'] ?? false,
        priority: Priority.values[json['priority'] ?? 1],
        createdAt: DateTime.parse(json['createdAt']),
      );

  Task copyWith({
    String? title,
    String? description,
    bool? isCompleted,
    Priority? priority,
  }) {
    return Task(
      id: this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      createdAt: this.createdAt,
    );
  }
}

// --- Хранилище задач (с сохранением в SharedPreferences) ---
class TaskRepository {
  static const String _storageKey = 'tasks';

  Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString(_storageKey);
    if (tasksJson == null || tasksJson.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(tasksJson);
    return decoded.map((item) => Task.fromJson(item)).toList();
  }

  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final String tasksJson =
        jsonEncode(tasks.map((task) => task.toJson()).toList());
    await prefs.setString(_storageKey, tasksJson);
  }
}

// --- Главное приложение ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мои задачи',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const TaskListScreen(),
    );
  }
}

// --- Экран со списком задач ---
class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  List<Task> _filteredTasks = [];
  final TaskRepository _repository = TaskRepository();
  String _filter = 'all'; // all, active, completed

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await _repository.loadTasks();
    setState(() {
      _tasks = tasks;
      _applyFilter();
    });
  }

  void _applyFilter() {
    setState(() {
      switch (_filter) {
        case 'active':
          _filteredTasks = _tasks.where((t) => !t.isCompleted).toList();
          break;
        case 'completed':
          _filteredTasks = _tasks.where((t) => t.isCompleted).toList();
          break;
        default:
          _filteredTasks = List.from(_tasks);
      }
    });
  }

  Future<void> _saveAndUpdate() async {
    await _repository.saveTasks(_tasks);
    _applyFilter();
  }

  void _addTask(Task task) {
    setState(() {
      _tasks.add(task);
    });
    _saveAndUpdate();
  }

  void _updateTask(Task updatedTask) {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      setState(() {
        _tasks[index] = updatedTask;
      });
      _saveAndUpdate();
    }
  }

  void _deleteTask(String id) {
    setState(() {
      _tasks.removeWhere((t) => t.id == id);
    });
    _saveAndUpdate();
  }

  void _toggleComplete(Task task) {
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    _updateTask(updated);
  }

  void _showEditDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) {
        return TaskEditDialog(
          task: task,
          onSave: (updated) => _updateTask(updated),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои задачи'),
        centerTitle: true,
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _filter = value;
                _applyFilter();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Все')),
              const PopupMenuItem(value: 'active', child: Text('Активные')),
              const PopupMenuItem(value: 'completed', child: Text('Выполненные')),
            ],
          ),
        ],
      ),
      body: _filteredTasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Нет задач',
                    style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredTasks.length,
              itemBuilder: (context, index) {
                final task = _filteredTasks[index];
                return Dismissible(
                  key: Key(task.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _deleteTask(task.id),
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Checkbox(
                        value: task.isCompleted,
                        onChanged: (_) => _toggleComplete(task),
                        activeColor: const Color(0xFF6C63FF),
                      ),
                      title: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted ? Colors.grey : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (task.description.isNotEmpty)
                            Text(task.description),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildPriorityChip(task.priority),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(task.createdAt),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showEditDialog(task),
                      ),
                      onTap: () => _showEditDialog(task),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: TaskForm(
                onSave: (task) {
                  _addTask(task);
                  Navigator.pop(context);
                },
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Добавить задачу'),
      ),
    );
  }

  Widget _buildPriorityChip(Priority priority) {
    Color color;
    String label;
    switch (priority) {
      case Priority.high:
        color = Colors.red;
        label = 'Высокий';
        break;
      case Priority.medium:
        color = Colors.orange;
        label = 'Средний';
        break;
      case Priority.low:
        color = Colors.green;
        label = 'Низкий';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

// --- Виджет формы создания/редактирования задачи ---
class TaskForm extends StatefulWidget {
  final Task? task;
  final ValueChanged<Task> onSave;

  const TaskForm({super.key, this.task, required this.onSave});

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  Priority _priority = Priority.medium;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descController = TextEditingController(text: widget.task?.description ?? '');
    if (widget.task != null) {
      _priority = widget.task!.priority;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название задачи')),
      );
      return;
    }

    final task = widget.task?.copyWith(
          title: title,
          description: _descController.text.trim(),
          priority: _priority,
        ) ??
        Task(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          description: _descController.text.trim(),
          priority: _priority,
        );

    widget.onSave(task);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.task == null ? 'Новая задача' : 'Редактировать задачу',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              labelText: 'Описание (необязательно)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          const Text('Приоритет:'),
          const SizedBox(height: 8),
          Row(
            children: Priority.values.map((p) {
              final selected = _priority == p;
              Color color;
              String label;
              switch (p) {
                case Priority.low:
                  color = Colors.green;
                  label = 'Низкий';
                  break;
                case Priority.medium:
                  color = Colors.orange;
                  label = 'Средний';
                  break;
                case Priority.high:
                  color = Colors.red;
                  label = 'Высокий';
                  break;
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _priority = p),
                  selectedColor: color.withOpacity(0.3),
                  labelStyle: TextStyle(
                    color: selected ? color : Colors.black87,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(widget.task == null ? 'Добавить' : 'Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Диалог редактирования задачи ---
class TaskEditDialog extends StatelessWidget {
  final Task task;
  final ValueChanged<Task> onSave;

  const TaskEditDialog({super.key, required this.task, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: TaskForm(
        task: task,
        onSave: (updated) {
          onSave(updated);
          Navigator.pop(context);
        },
      ),
    );
  }
}