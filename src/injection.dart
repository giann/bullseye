import 'logger.dart';

class Dependency<T> {
  T instance;

  Dependency(this.instance);

  @override
  bool operator ==(dynamic other) => other is T;

  @override
  int get hashCode => T.hashCode;
}

class DependencyRegistry with Logged {
  static DependencyRegistry current = DependencyRegistry();

  Set<Dependency> dependencies = {};

  T? get<T>() {
    try {
      return dependencies.firstWhere((dep) => dep.instance is T).instance as T;
    } on StateError catch (_) {
      return null;
    }
  }

  dynamic getRuntime(Type t) {
    try {
      return dependencies.firstWhere((dep) => dep.instance.runtimeType == t).instance;
    } on StateError catch (_) {
      return null;
    }
  }

  void put<T>(T instance) {
    dependencies.add(Dependency<T>(instance));

    logger.config('Service `$T` registered');
  }
}
