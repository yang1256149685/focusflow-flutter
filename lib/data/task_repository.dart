import 'package:shared_preferences/shared_preferences.dart';

abstract class TaskRepository {
  Future<String?> load();
  Future<void> save(String data);
}

class LocalTaskRepository implements TaskRepository {
  static const key = 'focusflow.v1';
  @override
  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> save(String data) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, data)) {
      throw StateError('本机存储写入失败');
    }
  }
}
