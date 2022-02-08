import 'dart:mirrors';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'package:mysql1/mysql1.dart';
import 'package:uuid/uuid.dart';

import '../logger.dart';
import 'orm.dart';

@immutable
class NoMatchingField implements Exception {
  final String? _message;

  NoMatchingField([this._message]);

  @override
  String toString() => _message ?? 'No matching field';
}

class Repository<T extends Entity> {
  final String table;
  final MySqlOrm orm;

  Repository({required this.orm, required this.table});

  T _produceFrom(ResultRow row) {
    InstanceMirror instanceMirror = reflect(this);
    ClassMirror classMirror = instanceMirror.type;
    ClassMirror t = classMirror.typeArguments.first as ClassMirror;

    // Get constructor
    Symbol constructor = (t.declarations.entries.firstWhere((MapEntry<Symbol, DeclarationMirror> element) {
      DeclarationMirror decl = element.value;

      if (decl is MethodMirror) {
        return decl.isConstructor && MirrorSystem.getName(decl.constructorName) == 'withId';
      }

      return false;
    }).value as MethodMirror)
        .constructorName;

    return t.newInstance(constructor, row.values ?? <dynamic>[]).reflectee as T;
  }

  Map<String, Object> _instanceToMap(T instance, [Map<String, Object>? values, ClassMirror? superclass]) {
    values = values ?? {};

    InstanceMirror instanceMirror = reflect(instance);
    ClassMirror classMirror = superclass ?? instanceMirror.type;

    classMirror.declarations.forEach((Symbol key, DeclarationMirror decl) {
      if (decl is VariableMirror && !decl.isPrivate) {
        values![MirrorSystem.getName(decl.simpleName)] = instanceMirror.getField(decl.simpleName).reflectee as Object;
      }
    });

    if (classMirror.superclass != null) {
      return _instanceToMap(instance, values, classMirror.superclass);
    }

    return values;
  }

  Future<List<T>> find({
    String? id,
    List<String> conditions = const <String>[],
    List<Object> params = const <Object>[],
  }) async {
    String whereClause = ' where ${id != null ? 'id = UUID_TO_BIN(?)' : ''}'
        ' ${id != null && conditions.isNotEmpty ? ' AND ' : ''}'
        ' ${conditions.join(' AND ')}';

    Results results = await orm.select(
      '* from $table${id != null || conditions.isNotEmpty ? whereClause : ''}',
      params: [
        if (id != null) id,
        ...params,
      ],
    ).execute();

    return results.map<T>((ResultRow row) => _produceFrom(row)).toList();
  }

  Future<int> delete({
    T? instance,
    String? id,
    List<String> conditions = const <String>[],
    List<Object> params = const <Object>[],
  }) async {
    Results results = await orm.delete(
      table,
      conditions: id != null || conditions.isNotEmpty || instance != null
          ? [
              if (id != null || instance != null) 'id = ?',
              ...conditions,
            ]
          : null,
      params: [
        if (id != null || instance != null) id ?? instance?.id ?? '',
        ...params,
      ],
    ).execute();

    return results.affectedRows ?? 0;
  }

  Future<void> insert(T instance) => orm.insert(table, _instanceToMap(instance)).execute();
}

@immutable
abstract class Entity {
  final String id;

  Entity([String? id]) : id = id ?? Uuid().v4();
}

class Person extends Entity {
  final String firstname;
  final String lastname;
  final int age;

  Person(this.firstname, this.lastname, this.age) : super();

  Person.withId(String id, this.firstname, this.lastname, this.age) : super(id);
}

void main() async {
  final LoggerService loggerService = LoggerService()..init();
  final Logger logger = loggerService.general;

  MySqlOrm o = MySqlOrm(ConnectionSettings(
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: 'test',
    db: 'test',
  ));

  Repository<Person> repository = Repository<Person>(orm: o, table: 'person');

  await o.connect();

  Person newPerson = Person('Joe', 'Doe', 23);

  await repository.insert(newPerson);

  List<Person> persons = await repository.find();

  if (persons.isNotEmpty) {
    logger.warning(
      'Hello ${persons.first.firstname} ${persons.first.lastname} you are ${persons.first.age} years old!',
    );
  } else {
    logger.severe('Not found');
  }

  await repository.delete();

  o.close();
}
