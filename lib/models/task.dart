import 'dart:math';

class Task {
  final String id, title, notes, project, status, priority;
  final DateTime? dueDate, completedAt;
  final DateTime createdAt, updatedAt;
  const Task({
    required this.id,
    required this.title,
    this.notes = '',
    this.project = '个人',
    this.status = 'todo',
    this.priority = 'medium',
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });
  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x100000000)}';
  bool get done => status == 'done';
  bool overdue(DateTime now) =>
      !done &&
      dueDate != null &&
      dueDate!.isBefore(DateTime(now.year, now.month, now.day));
  Task copyWith({
    String? title,
    String? notes,
    String? project,
    String? status,
    String? priority,
    DateTime? dueDate,
    bool clearDue = false,
  }) {
    final nextStatus = status ?? this.status;
    return Task(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      project: project ?? this.project,
      status: nextStatus,
      priority: priority ?? this.priority,
      dueDate: clearDue ? null : dueDate ?? this.dueDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      completedAt: nextStatus == 'done' ? completedAt ?? DateTime.now() : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'project': project,
    'status': status,
    'priority': priority,
    'dueDate': dueDate == null
        ? null
        : '${dueDate!.year.toString().padLeft(4, '0')}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };
  factory Task.fromJson(Map<String, dynamic> data) {
    String field(String key, int limit, {bool empty = false}) {
      final v = data[key];
      if (v is! String || v.length > limit || (!empty && v.trim().isEmpty)) {
        throw FormatException('字段 $key 不合法');
      }
      return v.trim();
    }

    final id = field('id', 100),
        title = field('title', 100),
        notes = field('notes', 2000, empty: true),
        project = field('project', 40),
        status = field('status', 10),
        priority = field('priority', 10);
    if (!['todo', 'doing', 'done'].contains(status) ||
        !['low', 'medium', 'high'].contains(priority)) {
      throw const FormatException('状态或优先级不合法');
    }
    DateTime? date(String key) {
      if (data[key] == null) {
        return null;
      }
      if (data[key] is! String) {
        throw const FormatException('日期类型不合法');
      }
      final result = DateTime.tryParse(data[key]);
      if (result == null) {
        throw const FormatException('日期不合法');
      }
      if (key == 'dueDate' &&
          result.toIso8601String().substring(0, 10) != data[key]) {
        throw const FormatException('截止日期不合法');
      }
      return result;
    }

    final created = date('createdAt'),
        updated = date('updatedAt'),
        completed = date('completedAt');
    if (created == null ||
        updated == null ||
        (status == 'done') != (completed != null)) {
      throw const FormatException('任务时间状态不一致');
    }
    return Task(
      id: id,
      title: title,
      notes: notes,
      project: project,
      status: status,
      priority: priority,
      dueDate: date('dueDate'),
      createdAt: created,
      updatedAt: updated,
      completedAt: completed,
    );
  }
}
