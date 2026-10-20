import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/data/task_repository.dart';
import 'package:focusflow/models/task.dart';
import 'package:focusflow/state/task_store.dart';

class MemoryRepo implements TaskRepository {
  String? data;
  bool fail = false;
  @override
  Future<String?> load() async => data;
  @override
  Future<void> save(String value) async {
    if (fail) {
      throw StateError('disk full');
    }
    data = value;
  }
}

void main() {
  test('CRUD and restart preserve data; clearing does not reseed', () async {
    final repo = MemoryRepo(), store = TaskStore(MemoryRepo());
    final s = TaskStore(repo);
    await s.initialize();
    await s.clear();
    expect(s.completionRate, 0);
    final now = DateTime.now();
    final t = Task(id: 'test', title: '测试任务', createdAt: now, updatedAt: now);
    await s.put(t);
    await s.put(t.copyWith(status: 'done'));
    expect(s.completed, 1);
    expect(s.tasks.single.completedAt, isNotNull);
    await s.put(s.tasks.single.copyWith(status: 'todo'));
    expect(s.completed, 0);
    expect(s.tasks.single.completedAt, isNull);
    final next = TaskStore(repo);
    await next.initialize();
    expect(next.tasks.single.title, '测试任务');
    await next.remove('test');
    final empty = TaskStore(repo);
    await empty.initialize();
    expect(empty.tasks, isEmpty);
    expect(store.tasks, isEmpty);
  });
  test(
    'failed persistence rolls back memory and later writes still work',
    () async {
      final repo = MemoryRepo(), s = TaskStore(MemoryRepo());
      final store = TaskStore(repo);
      await store.initialize();
      final count = store.tasks.length;
      repo.fail = true;
      await expectLater(store.clear(), throwsStateError);
      expect(store.tasks.length, count);
      repo.fail = false;
      await store.clear();
      expect(store.tasks, isEmpty);
      expect(s.tasks, isEmpty);
    },
  );
  test('invalid import is atomic, duplicates and dates rejected', () async {
    final s = TaskStore(MemoryRepo());
    await s.initialize();
    final raw = s.exportJson();
    await expectLater(
      Future.sync(() => s.importJson('{bad')),
      throwsA(isA<FormatException>()),
    );
    expect(s.exportJson(), raw);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    (data['tasks'] as List).add((data['tasks'] as List).first);
    expect(() => s.importJson(jsonEncode(data)), throwsFormatException);
    final bad = jsonDecode(raw) as Map<String, dynamic>;
    bad['tasks'][0]['dueDate'] = '2026-02-31';
    expect(() => s.importJson(jsonEncode(bad)), throwsFormatException);
    await s.clear();
    await s.importJson(raw);
    expect(s.tasks.length, 7);
  });
  test(
    'concurrent mutations keep every task; overdue ignores completed tasks',
    () async {
      final s = TaskStore(MemoryRepo());
      await s.initialize();
      await s.clear();
      final now = DateTime(2026, 10, 20);
      await Future.wait(
        List.generate(
          20,
          (i) => s.put(
            Task(id: '$i', title: 'task $i', createdAt: now, updatedAt: now),
          ),
        ),
      );
      expect(s.tasks.length, 20);
      final late = Task(
        id: 'late',
        title: 'Late',
        dueDate: DateTime(2026, 10, 19),
        createdAt: now,
        updatedAt: now,
      );
      expect(late.overdue(now), isTrue);
      expect(late.copyWith(status: 'done').overdue(now), isFalse);
    },
  );
}
