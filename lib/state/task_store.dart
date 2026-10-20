import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../data/task_repository.dart';

class TaskStore extends ChangeNotifier {
  final TaskRepository repository;
  TaskStore(this.repository);
  List<Task> _tasks = [];
  List<Task> get tasks => List.unmodifiable(_tasks);
  String name = '创作者';
  bool dark = false;
  Future<void> _queue = Future.value();
  Map<String, dynamic> _payload(List<Task> tasks, String name, bool dark) => {
    'schemaVersion': 1,
    'name': name,
    'dark': dark,
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };
  static List<Task> parseTasks(Map<String, dynamic> data) {
    if (data['schemaVersion'] != 1 ||
        data['tasks'] is! List ||
        (data['tasks'] as List).length > 5000 ||
        data['name'] is! String ||
        (data['name'] as String).length > 40 ||
        (data['name'] as String).trim().isEmpty ||
        data['dark'] is! bool) {
      throw const FormatException('不支持的数据格式或版本');
    }
    final tasks = (data['tasks'] as List)
        .map((t) => Task.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList();
    if (tasks.map((t) => t.id).toSet().length != tasks.length) {
      throw const FormatException('任务 ID 重复');
    }
    return tasks;
  }

  Future<void> initialize() async {
    final raw = await repository.load();
    if (raw == null) {
      _tasks = samples();
      await repository.save(exportJson());
    } else {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _tasks = parseTasks(data);
      name = data['name'];
      dark = data['dark'];
    }
    notifyListeners();
  }

  Future<void> _mutate(
    List<Task> Function() action, {
    String? newName,
    bool? newDark,
  }) {
    final operation = _queue.then((_) async {
      final next = action();
      final nextName = newName ?? name;
      final nextDark = newDark ?? dark;
      await repository.save(jsonEncode(_payload(next, nextName, nextDark)));
      _tasks = next;
      name = nextName;
      dark = nextDark;
      notifyListeners();
    });
    _queue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> put(Task task) =>
      _mutate(() => [..._tasks.where((t) => t.id != task.id), task]);
  Future<void> remove(String id) =>
      _mutate(() => _tasks.where((t) => t.id != id).toList());
  Future<void> clear() => _mutate(() => []);
  Future<void> resetSamples() => _mutate(samples);
  Future<void> preferences({String? name, bool? dark}) =>
      _mutate(() => [..._tasks], newName: name, newDark: dark);
  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(_payload(_tasks, name, dark));
  Future<void> importJson(String raw) {
    if (raw.length > 10000000) {
      throw const FormatException('导入内容过大');
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final next = parseTasks(data);
    return _mutate(() => next, newName: data['name'], newDark: data['dark']);
  }

  int get completed => _tasks.where((t) => t.done).length;
  double get completionRate => _tasks.isEmpty ? 0 : completed / _tasks.length;
  static List<Task> samples() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const titles = [
      '梳理新项目的需求与交付清单',
      '完善作品集首页与项目介绍',
      '完成任务管理 App 的交互验证',
      '整理本周学习笔记',
      '阅读一章设计系统指南',
      '为知识库编写原创示例文档',
      '检查发布前的隐私与安全事项',
    ];
    return List.generate(
      titles.length,
      (i) => Task(
        id: 'sample-$i',
        title: titles[i],
        notes: '个人原创作品的公开示例任务，可编辑或删除。',
        project: ['作品集', '作品集', '移动开发', '个人成长', '个人成长', '作品集', '移动开发'][i],
        priority: i < 3 ? 'high' : 'medium',
        status: i == 0
            ? 'doing'
            : i >= 4
            ? 'done'
            : 'todo',
        createdAt: now.subtract(Duration(days: i + 1)),
        updatedAt: now,
        completedAt: i >= 4 ? now : null,
        dueDate: today.add(
          Duration(
            days: i == 3
                ? -1
                : i > 3
                ? 2
                : 0,
          ),
        ),
      ),
    );
  }
}
