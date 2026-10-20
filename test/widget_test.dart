import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/main.dart';
import 'package:focusflow/data/task_repository.dart';
import 'package:focusflow/state/task_store.dart';

class Repo implements TaskRepository {
  String? data;
  @override
  Future<String?> load() async => data;
  @override
  Future<void> save(String value) async {
    data = value;
  }
}

void main() {
  testWidgets('real task form validates and saves', (tester) async {
    await tester.pumpWidget(FocusFlowApp(store: TaskStore(Repo())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('新建任务'));
    await tester.tap(find.text('新建任务'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存任务'));
    await tester.tap(find.text('保存任务'));
    await tester.pumpAndSettle();
    expect(find.text('请输入任务标题'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '从测试创建的真实任务');
    await tester.ensureVisible(find.text('保存任务'));
    await tester.tap(find.text('保存任务'));
    await tester.pumpAndSettle();
    expect(find.text('从测试创建的真实任务'), findsOneWidget);
  });
}
