import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/task_repository.dart';
import 'models/task.dart';
import 'state/task_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FocusFlowApp(store: TaskStore(LocalTaskRepository())));
}

const ink = Color(0xff19312e),
    accent = Color(0xff247969),
    paper = Color(0xfff5f6f2);

class FocusFlowApp extends StatefulWidget {
  final TaskStore store;
  const FocusFlowApp({super.key, required this.store});
  @override
  State<FocusFlowApp> createState() => _FocusFlowAppState();
}

class _FocusFlowAppState extends State<FocusFlowApp> {
  late final Future<void> ready = widget.store.initialize();
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (_, _) => MaterialApp(
      title: '拾序 FocusFlow · 让每一步都有方向',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      themeMode: widget.store.dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: accent),
        scaffoldBackgroundColor: paper,
        fontFamily: 'sans-serif',
        appBarTheme: const AppBarTheme(backgroundColor: paper),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
        fontFamily: 'sans-serif',
      ),
      home: FutureBuilder(
        future: ready,
        builder: (_, snap) {
          if (snap.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: SelectableText(
                    '本机数据读取失败，未覆盖已有数据。\n${snap.error}\n请检查浏览器存储权限或使用备份恢复。',
                  ),
                ),
              ),
            );
          }
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return TaskHome(store: widget.store);
        },
      ),
    ),
  );
}

class TaskHome extends StatefulWidget {
  final TaskStore store;
  const TaskHome({super.key, required this.store});
  @override
  State<TaskHome> createState() => _TaskHomeState();
}

class _TaskHomeState extends State<TaskHome> {
  final searchController = TextEditingController();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  int tab = 0;
  String query = '', project = '全部项目', status = '全部状态', sort = '截止时间';
  TaskStore get store => widget.store;
  static const tabs = ['今日概览', '所有任务', '进度统计', '我的设置'];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.checklist_rounded,
    Icons.insights_outlined,
    Icons.tune_rounded,
  ];
  Future<void> safely(Future<void> Function() action, [String? message]) async {
    try {
      await action();
      if (mounted && message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('操作未保存，请检查数据格式或本机存储权限。')));
      }
    }
  }

  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> edit([Task? task]) async {
    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskEditor(task: task),
    );
    if (result != null) {
      await safely(() => store.put(result), '任务已保存');
    }
  }

  List<Task> get filtered {
    final today = DateTime.now();
    final list = store.tasks
        .where(
          (t) =>
              (tab != 0 ||
                  (!t.done &&
                      (t.dueDate == null ||
                          !t.dueDate!.isAfter(
                            DateTime(today.year, today.month, today.day),
                          )))) &&
              (query.isEmpty ||
                  '${t.title} ${t.notes}'.toLowerCase().contains(
                    query.toLowerCase(),
                  )) &&
              (project == '全部项目' || t.project == project) &&
              (status == '全部状态' ||
                  t.status ==
                      {'待办': 'todo', '进行中': 'doing', '已完成': 'done'}[status]),
        )
        .toList();
    list.sort((a, b) {
      if (sort == '优先级') {
        return ['high', 'medium', 'low']
            .indexOf(a.priority)
            .compareTo(['high', 'medium', 'low'].indexOf(b.priority));
      }
      return (a.dueDate ?? DateTime(9999)).compareTo(
        b.dueDate ?? DateTime(9999),
      );
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide) _sidebar(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 36 : 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!wide)
                              const Icon(Icons.spa_outlined, color: accent),
                            if (!wide) const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                wide
                                    ? 'PERSONAL WORKSPACE  /  个人工作空间'
                                    : '拾序 FocusFlow',
                                style: TextStyle(
                                  fontSize: wide ? 12 : 17,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (wide)
                              const Chip(
                                label: Text('本机存储 · 离线可用'),
                                avatar: Icon(Icons.lock_outline, size: 16),
                              ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Text(
                          tabs[tab],
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            '把注意力留给重要的事，一步一步向前。',
                            '让每一个想法，都有清晰的下一步。',
                            '看见自己的进步，让努力有迹可循。',
                            '属于你的节奏，也属于你的数据。',
                          ][tab],
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 26),
                        if (tab == 0) ...[_hero(), const SizedBox(height: 24)],
                        if (tab < 2) ...[
                          _filters(),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tab == 0 ? '今日与待跟进' : '任务清单',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${filtered.length} 项',
                                style: const TextStyle(color: accent),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: () => edit(),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('新建任务'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (filtered.isEmpty)
                            _empty()
                          else
                            ...filtered.map(_taskCard),
                        ],
                        if (tab == 2) _statistics(),
                        if (tab == 3) _settings(),
                        const SizedBox(height: 28),
                        Text(
                          '个人原创作品 · 示例数据可自由编辑 · AI 辅助开发',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) => setState(() {
                tab = v;
                query = '';
                searchController.clear();
                project = '全部项目';
                status = '全部状态';
              }),
              destinations: List.generate(
                4,
                (i) =>
                    NavigationDestination(icon: Icon(icons[i]), label: tabs[i]),
              ),
            ),
    );
  }

  Widget _sidebar() => Container(
    width: 225,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        right: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: .12),
        ),
      ),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            CircleAvatar(
              backgroundColor: accent,
              child: Icon(Icons.spa_outlined, color: Colors.white),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '拾序',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                Text(
                  'F O C U S F L O W',
                  style: TextStyle(fontSize: 9, color: accent),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 48),
        const Padding(
          padding: EdgeInsets.only(left: 14),
          child: Text(
            '我的工作台',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          4,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              selected: tab == i,
              selectedTileColor: accent.withValues(alpha: .10),
              leading: Icon(icons[i], color: tab == i ? accent : null),
              title: Text(tabs[i], style: const TextStyle(fontSize: 14)),
              onTap: () => setState(() {
                tab = i;
                query = '';
                searchController.clear();
                project = '全部项目';
                status = '全部状态';
              }),
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.eco_outlined, color: accent),
              SizedBox(height: 10),
              Text(
                '少一点忙乱\n多一点从容',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '从完成眼前的一件小事开始。',
                style: TextStyle(fontSize: 11, color: accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('${store.name} · 本机档案', style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
  Widget _hero() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xff204c43), Color(0xff327d68)],
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '你好，${store.name}  ☀',
          style: const TextStyle(color: Color(0xffcae3d6), fontSize: 13),
        ),
        const SizedBox(height: 12),
        const Text(
          '专注当下，\n让重要的事有序发生。',
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            height: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _heroStat(
                '${store.tasks.length - store.completed}',
                '待完成任务',
              ),
            ),
            Expanded(child: _heroStat('${store.completed}', '已完成任务')),
            Expanded(
              child: _heroStat(
                '${(store.completionRate * 100).round()}%',
                '总完成率',
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Widget _heroStat(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(color: Color(0xffc7ded2), fontSize: 11),
      ),
    ],
  );
  Widget _filters() {
    final projects = [
      '全部项目',
      ...store.tasks.map((t) => t.project).toSet().toList()..sort(),
    ];
    if (!projects.contains(project)) {
      project = '全部项目';
    }
    return Column(
      children: [
        TextField(
          onChanged: (v) => setState(() => query = v),
          controller: searchController,
          decoration: InputDecoration(
            hintText: '搜索任务或备注…',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            drop(project, projects, (v) => setState(() => project = v)),
            drop(status, [
              '全部状态',
              '待办',
              '进行中',
              '已完成',
            ], (v) => setState(() => status = v)),
            drop(sort, ['截止时间', '优先级'], (v) => setState(() => sort = v)),
            TextButton(
              onPressed: () => setState(() {
                query = '';
                searchController.clear();
                project = '全部项目';
                status = '全部状态';
              }),
              child: const Text('清空筛选'),
            ),
          ],
        ),
      ],
    );
  }

  Widget drop(
    String selected,
    List<String> values,
    ValueChanged<String> changed,
  ) => DropdownButton<String>(
    value: selected,
    underline: const SizedBox(),
    borderRadius: BorderRadius.circular(12),
    items: values
        .map(
          (v) => DropdownMenuItem(
            value: v,
            child: Text(v, style: const TextStyle(fontSize: 13)),
          ),
        )
        .toList(),
    onChanged: (v) {
      if (v != null) {
        changed(v);
      }
    },
  );
  Widget _taskCard(Task t) {
    final color = t.priority == 'high' ? const Color(0xffbf7550) : accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: .1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        leading: Checkbox(
          value: t.done,
          onChanged: (_) => safely(
            () => store.put(t.copyWith(status: t.done ? 'todo' : 'done')),
          ),
        ),
        title: Text(
          t.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            decoration: t.done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              Text(
                t.project,
                style: const TextStyle(fontSize: 11, color: accent),
              ),
              Text(
                {'todo': '待办', 'doing': '进行中', 'done': '已完成'}[t.status]!,
                style: const TextStyle(fontSize: 11),
              ),
              Text(
                '${{'high': '高', 'medium': '中', 'low': '低'}[t.priority]}优先级',
                style: TextStyle(fontSize: 11, color: color),
              ),
              if (t.dueDate != null)
                Text(
                  '${t.overdue(DateTime.now()) ? '已逾期 · ' : ''}${t.dueDate!.month}月${t.dueDate!.day}日',
                  style: TextStyle(
                    fontSize: 11,
                    color: t.overdue(DateTime.now())
                        ? Colors.deepOrange
                        : Colors.grey,
                  ),
                ),
            ],
          ),
        ),
        onTap: () => edit(t),
        trailing: IconButton(
          tooltip: '删除任务',
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () async {
            if (await confirm('删除任务？', '“${t.title}”将被删除。')) {
              await safely(() => store.remove(t.id), '任务已删除');
            }
          },
        ),
      ),
    );
  }

  Widget _empty() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(44),
    child: const Column(
      children: [
        Icon(Icons.check_circle_outline, size: 46, color: accent),
        SizedBox(height: 16),
        Text(
          '这里暂时没有任务',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Text('试试调整筛选，或为下一步新建一个任务。', textAlign: TextAlign.center),
      ],
    ),
  );
  Widget _statistics() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _hero(),
      const SizedBox(height: 24),
      const Text(
        '项目完成进度',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 18),
      if (store.tasks.isEmpty) _empty(),
      ...store.tasks.map((t) => t.project).toSet().map((p) {
        final list = store.tasks.where((t) => t.project == p).toList();
        final count = list.where((t) => t.done).length;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(p)),
                    Text('$count / ${list.length}'),
                  ],
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: count / list.length,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(5),
                ),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: 16),
      const Text('统计根据当前本机任务实时计算，不包含云端同步数据。', style: TextStyle(fontSize: 12)),
    ],
  );
  Widget _settings() => Column(
    children: [
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('${store.name} · 本机档案'),
              subtitle: const Text('仅用于本机显示，不是远程账号'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                final controller = TextEditingController(text: store.name);
                final value = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('本机显示名'),
                    content: TextField(controller: controller, maxLength: 40),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () {
                          if (controller.text.trim().isNotEmpty) {
                            Navigator.pop(ctx, controller.text.trim());
                          }
                        },
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                );
                if (value != null) {
                  await safely(() => store.preferences(name: value));
                }
              },
            ),
            SwitchListTile(
              title: const Text('深色主题'),
              subtitle: const Text('把注意力留给内容'),
              value: store.dark,
              onChanged: (v) => safely(() => store.preferences(dark: v)),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('导出 JSON 备份'),
              subtitle: const Text('复制到剪贴板，也可查看完整文本'),
              onTap: () async {
                final raw = store.exportJson();
                await Clipboard.setData(ClipboardData(text: raw));
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('备份已复制'),
                      content: SizedBox(
                        width: 480,
                        child: SingleChildScrollView(
                          child: SelectableText(raw),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('完成'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.input_outlined),
              title: const Text('从 JSON 恢复'),
              subtitle: const Text('校验通过后替换当前任务和设置'),
              onTap: _import,
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('恢复原创示例'),
              onTap: () async {
                if (await confirm('恢复示例？', '将替换当前任务；建议先导出备份。')) {
                  await safely(store.resetSamples);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('清空所有任务'),
              onTap: () async {
                if (await confirm('清空所有任务？', '此操作仅影响拾序的本机任务；建议先导出备份。')) {
                  await safely(store.clear);
                }
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '你的数据，留在你的设备',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12),
              Text(
                '本作品不发送任务到服务器，没有云端账号。浏览器数据会受清理网站数据、无痕模式或存储权限影响，请定期备份。任务以明文保存在本机，请勿填写密码或敏感资料。',
              ),
              SizedBox(height: 16),
              Text(
                '拾序 FocusFlow 1.0 · 个人原创作品\nFlutter 跨平台开发 · AI 辅助实现',
                style: TextStyle(fontSize: 12, color: accent),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Future<void> _import() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('粘贴 JSON 备份'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            maxLines: 9,
            decoration: const InputDecoration(hintText: '粘贴从拾序导出的 JSON'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('校验并继续'),
          ),
        ],
      ),
    );
    if (raw != null && await confirm('替换本机数据？', '将先校验全部数据；校验失败会保留原数据。')) {
      await safely(() => store.importJson(raw), '恢复成功');
    }
  }
}

class TaskEditor extends StatefulWidget {
  final Task? task;
  const TaskEditor({super.key, this.task});
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.task?.title);
  late final notes = TextEditingController(text: widget.task?.notes);
  late final project = TextEditingController(
    text: widget.task?.project ?? '个人',
  );
  late String status = widget.task?.status ?? 'todo',
      priority = widget.task?.priority ?? 'medium';
  late DateTime? due = widget.task?.dueDate;
  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    project.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.task == null ? '为下一步留个位置' : '编辑任务',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text('清晰的一小步，是有序的开始。'),
            const SizedBox(height: 24),
            TextFormField(
              controller: title,
              autofocus: false,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: '任务标题 *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '请输入任务标题' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: notes,
              maxLength: 2000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '任务备注',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: project,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '所属项目',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '请输入项目名称' : null,
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: '优先级'),
                    items: const [
                      DropdownMenuItem(value: 'high', child: Text('高优先级')),
                      DropdownMenuItem(value: 'medium', child: Text('中优先级')),
                      DropdownMenuItem(value: 'low', child: Text('低优先级')),
                    ],
                    onChanged: (v) => priority = v!,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: '状态'),
                    items: const [
                      DropdownMenuItem(value: 'todo', child: Text('待办')),
                      DropdownMenuItem(value: 'doing', child: Text('进行中')),
                      DropdownMenuItem(value: 'done', child: Text('已完成')),
                    ],
                    onChanged: (v) => status = v!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final result = await showDatePicker(
                      context: context,
                      initialDate: due ?? now,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (result != null) {
                      setState(() => due = result);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 17),
                  label: Text(
                    due == null
                        ? '设置截止日期'
                        : '${due!.year}年${due!.month}月${due!.day}日',
                  ),
                ),
                if (due != null)
                  IconButton(
                    onPressed: () => setState(() => due = null),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (!form.currentState!.validate()) {
                        return;
                      }
                      final now = DateTime.now();
                      final task =
                          widget.task?.copyWith(
                            title: title.text.trim(),
                            notes: notes.text.trim(),
                            project: project.text.trim(),
                            priority: priority,
                            status: status,
                            dueDate: due,
                            clearDue: due == null,
                          ) ??
                          Task(
                            id: Task.newId(),
                            title: title.text.trim(),
                            notes: notes.text.trim(),
                            project: project.text.trim(),
                            priority: priority,
                            status: status,
                            dueDate: due,
                            createdAt: now,
                            updatedAt: now,
                            completedAt: status == 'done' ? now : null,
                          );
                      Navigator.pop(context, task);
                    },
                    child: const Text('保存任务'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
