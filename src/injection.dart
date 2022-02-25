import 'logger.dart';

class Dependency<T> {
  final T? _instance;
  final T Function()? builder;

  T get instance => _instance ?? builder!();

  Dependency({T? instance, this.builder}) : _instance = instance {
    if (instance == null && builder == null) {
      throw ArgumentError('Either provide an instance or a builder');
    }
  }

  @override
  bool operator ==(dynamic other) => other is T;

  @override
  int get hashCode => T.hashCode;
}

class DependencyRegistry with Logged {
  static DependencyRegistry current = DependencyRegistry();

  Set<Dependency> dependencies = {};

  T get<T>() => dependencies.firstWhere((dep) => dep.instance is T).instance as T;

  T? getOpt<T>() {
    try {
      return dependencies.firstWhere((dep) => dep.instance is T).instance as T;
    } catch (_) {}
  }

  dynamic getRuntime(Type t) {
    try {
      return dependencies.firstWhere((dep) => dep.instance.runtimeType == t).instance;
    } on StateError catch (_) {
      return null;
    }
  }

  void put<T>({T? instance, T Function()? builder}) {
    dependencies.add(Dependency<T>(instance: instance, builder: builder));

    logger.config('Service `$T` registered');
  }
}
