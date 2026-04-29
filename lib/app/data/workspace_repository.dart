import '../state/singleton_storage.dart';
import 'workspace_data.dart';

/// Workspace 数据访问的 repository 接口。
///
/// 提供类型化的 load/save 操作，消费方不需要关心底层序列化细节。
abstract interface class WorkspaceRepository {
  Future<WorkspaceData?> load();

  Future<void> save(WorkspaceData data);

  Future<void> clear();
}

/// 基于 [SingletonStorage] 的 repository 实现。
///
/// 将底层 `Map<String, Object?>` 序列化/反序列化委托给 [WorkspaceData]。
class StorageWorkspaceRepository implements WorkspaceRepository {
  StorageWorkspaceRepository(this._storage);

  final SingletonStorage _storage;

  @override
  Future<WorkspaceData?> load() async {
    final raw = await _storage.load();
    if (raw == null) return null;
    return WorkspaceData.fromJson(raw);
  }

  @override
  Future<void> save(WorkspaceData data) {
    return _storage.save(data.toJson());
  }

  @override
  Future<void> clear() {
    return _storage.clear();
  }
}

/// 纯内存实现，用于测试和 web 目标。
class InMemoryWorkspaceRepository implements WorkspaceRepository {
  WorkspaceData? _data;

  @override
  Future<WorkspaceData?> load() async => _data;

  @override
  Future<void> save(WorkspaceData data) async {
    _data = data;
  }

  @override
  Future<void> clear() async {
    _data = null;
  }
}
