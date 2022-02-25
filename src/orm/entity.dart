import 'dart:collection';
import 'dart:mirrors';
import 'package:meta/meta.dart';
import 'package:mysql1/mysql1.dart';
import 'package:uuid/uuid.dart';

import '../form.dart';
import '../injection.dart';
import '../utils/mirror.dart';
import 'orm.dart';

// Subset of MySQL column types
enum ColumnType {
  int,
  bigint,
  bit,
  decimal,
  money,
  numeric,
  smallint,
  smallmoney,
  tinyint,
  float,
  real,
  date,
  datetime,
  time,
  char,
  varchar,
  text,
  binary,
  image,
  timestamp,
  uniqueidentifier,
  xml,
}

// ANNOTATIONS

@immutable
class Entity {
  final String? table;

  const Entity({this.table});
}

const entity = Entity();

@immutable
class Column {
  final String? name;
  final ColumnType? columnType;
  final List<Validator> validators;
  final dynamic defaultValue;

  const Column({
    this.name,
    this.columnType,
    this.validators = const [],
    this.defaultValue,
  });
}

const column = Column();

@immutable
class PrimaryKey extends Column {
  const PrimaryKey({
    String? name,
    ColumnType? columnType,
    List<Validator> validators = const [],
  }) : super(
          name: name,
          columnType: columnType,
          validators: validators,
        );
}

const primaryKey = PrimaryKey();

@immutable
class Uuid4PrimaryKey extends PrimaryKey {
  const Uuid4PrimaryKey({
    String? name,
    ColumnType? columnType,
    List<Validator> validators = const [],
  }) : super(
          name: name,
          columnType: columnType,
          validators: validators,
        );
}

const uuid4PrimaryKey = Uuid4PrimaryKey();

@immutable
class InterpretedEntity<T> {
  late final String table;
  late final List<String> primaryKeys = [];
  late final LinkedHashMap<String, Column> columns = LinkedHashMap();
  // TODO
  // late final Map<String, dynamic> relations;

  static ColumnType _inferType(VariableMirror decl) {
    switch (decl.type.reflectedType) {
      case int:
        return ColumnType.int;
      case double:
        return ColumnType.float;
      case String:
        return ColumnType.varchar;
      case bool:
        return ColumnType.bit;
      case DateTime:
        return ColumnType.datetime;
    }

    throw InferedTypeException();
  }

  InterpretedEntity() {
    TypeMirror typeMirror = reflectType(T);
    ClassMirror classMirror = typeMirror is ClassMirror ? typeMirror : throw ArgumentError('Type is not a class');

    Entity? entityAnnotation;
    try {
      entityAnnotation =
          classMirror.metadata.firstWhere((metadata) => metadata.reflectee is Entity).reflectee as Entity;
    } on StateError catch (_) {}

    if (entityAnnotation == null) throw NotAnEntityException();

    // Table name is either specified by the @Entity annotation or by the class name
    table = entityAnnotation.table ?? MirrorSystem.getName(classMirror.simpleName).toLowerCase();

    for (DeclarationMirror decl in declarationsOf(classMirror)) {
      if (decl.isPrivate || decl is! VariableMirror) continue;

      Column? columnAnnotation;
      bool isPrimaryKey = false;
      for (InstanceMirror annotationMirror in decl.metadata) {
        dynamic annotation = annotationMirror.reflectee;

        if (annotation is PrimaryKey) {
          isPrimaryKey = true;
        }

        if (annotation is Column) {
          columnAnnotation = annotation;
        }
      }

      // Fields without a @Column annotation are ignored
      if (columnAnnotation != null) {
        // Omitted data are inferred
        Column columnDefinition;
        String name = columnAnnotation.name ?? MirrorSystem.getName(decl.simpleName);
        ColumnType colType = columnAnnotation.columnType ?? _inferType(decl);
        List<Validator> validators = columnAnnotation.validators;

        if (columnAnnotation is Uuid4PrimaryKey) {
          columnDefinition = Uuid4PrimaryKey(name: name, columnType: colType, validators: validators);
        } else if (columnAnnotation is PrimaryKey) {
          columnDefinition = PrimaryKey(name: name, columnType: colType, validators: validators);
        } else {
          columnDefinition = Column(
            name: columnAnnotation.name ?? MirrorSystem.getName(decl.simpleName),
            columnType: columnAnnotation.columnType ?? _inferType(decl),
            validators: columnAnnotation.validators,
          );
        }

        if (isPrimaryKey) {
          // TODO: should check that the field is not nullable, but dart:mirrors as no notion of null-safety
          primaryKeys.add(columnDefinition.name!);
        }

        columns[columnDefinition.name!] = columnDefinition;
      }
    }
  }

  Map<String, Object> getData(dynamic instance) {
    if (instance is! T) {
      throw ArgumentError('Argument is not instance of $T');
    }

    InstanceMirror instanceMirror = reflect(instance);

    Map<String, Object> data = {};
    for (Column column in columns.values) {
      InstanceMirror? field;

      try {
        field = instanceMirror.getField(Symbol(column.name!));
      } catch (_) {
        // Triggered a LateInitializationError (which we can't import in userland)
      }

      if (field == null && column is Uuid4PrimaryKey) {
        String id = Uuid().v4();
        instanceMirror.setField(Symbol(column.name!), id);
        data[column.name!] = id; // TODO: rely on MySQL to do that instead
      } else if (field != null && field.hasReflectee) {
        data[column.name!] = field.reflectee as Object;
      }
    }

    return data;
  }
}

class InferedTypeException implements Exception {
  final String? _message;

  InferedTypeException([this._message]);

  @override
  String toString() => _message ?? 'Could not infer column type';
}

class NotAnEntityException implements Exception {
  final String? _message;

  NotAnEntityException([this._message]);

  @override
  String toString() => _message ?? 'Not an Entity instance';
}

class Repository<T> {
  final InterpretedEntity _interpreted = InterpretedEntity<T>();

  Repository();

  T _produceFrom(ResultRow row) {
    TypeMirror typeMirror = reflectType(T);
    ClassMirror classMirror = typeMirror is ClassMirror ? typeMirror : throw ArgumentError('Type is not a class');

    // Get default constructor
    Symbol constructor = (classMirror.declarations.entries.firstWhere((MapEntry<Symbol, DeclarationMirror> element) {
      DeclarationMirror decl = element.value;

      if (decl is MethodMirror) {
        return decl.isConstructor && MirrorSystem.getName(decl.constructorName) == '';
      }

      return false;
    }).value as MethodMirror)
        .constructorName;

    T instance = classMirror.newInstance(constructor, <dynamic>[]).reflectee as T;
    InstanceMirror instanceMirror = reflect(instance);

    row.fields.forEach((String key, dynamic value) {
      instanceMirror.setField(Symbol(key), value);
    });

    return instance;
  }

  Future<T?> firstWhere({
    List<String> conditions = const <String>[],
    List<Object> params = const <Object>[],
  }) async {
    List<T> results = await find(
      conditions: conditions,
      params: params,
    );

    return results.isNotEmpty ? results.first : null;
  }

  Future<List<T>> find({
    List<String> conditions = const <String>[],
    List<Object> params = const <Object>[],
  }) async {
    final orm = DependencyRegistry.current.get<MySqlOrm>();

    String whereClause = ' where ${conditions.join(' AND ')}';

    Results results = await orm.select(
      '* from ${_interpreted.table}${conditions.isNotEmpty ? whereClause : ''}',
      params: [
        ...params,
      ],
    ).execute();

    return results.map<T>((ResultRow row) => _produceFrom(row)).toList();
  }

  Future<int> delete({
    T? instance,
    List<String> conditions = const [],
    List<Object> params = const [],
  }) async {
    final orm = DependencyRegistry.current.get<MySqlOrm>();

    Map<String, Object> data = instance != null ? _interpreted.getData(instance) : {};

    List<String> pkConditions = [];
    List<Object> pkParams = [];
    if (_interpreted.primaryKeys.isNotEmpty && instance != null) {
      for (String primaryKey in _interpreted.primaryKeys) {
        Column? pkColumn = _interpreted.columns[primaryKey];

        assert(pkColumn != null);
        if (pkColumn != null) {
          pkConditions.add('${pkColumn.name!}=?');
          pkParams.add(data[pkColumn.name!]!);
        }
      }
    }

    Results results = await orm.delete(
      _interpreted.table,
      conditions: [
        ...pkConditions,
        ...conditions,
      ],
      params: [
        ...pkParams,
        ...params,
      ],
    ).execute();

    return results.affectedRows ?? 0;
  }

  Future<void> insert(T instance) => DependencyRegistry.current
      .get<MySqlOrm>()
      .insert(
        _interpreted.table,
        _interpreted.getData(instance),
      )
      .execute();

  Future<void> update(T instance) => DependencyRegistry.current
      .get<MySqlOrm>()
      .update(
        _interpreted.table,
        _interpreted.getData(instance),
      )
      .execute();
}
