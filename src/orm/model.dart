import 'dart:mirrors';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'package:mysql1/mysql1.dart';

import '../logger.dart';
import 'orm.dart';

@immutable
class NoMatchingField implements Exception {
  final String? _message;

  NoMatchingField([this._message]);

  @override
  String toString() => _message ?? 'No matching field';
}

class Repository<T> {
  final String table;
  final Orm orm;

  Repository({required this.orm, required this.table});

  T _produceFrom(ResultRow row) {
    InstanceMirror instanceMirror = reflect(this);
    ClassMirror classMirror = instanceMirror.type;
    ClassMirror t = classMirror.typeArguments.first as ClassMirror;

    // Get constructor
    Symbol constructor = (t.declarations.entries.firstWhere((MapEntry<Symbol, DeclarationMirror> element) {
      DeclarationMirror decl = element.value;

      if (decl is MethodMirror) {
        return decl.isConstructor && MirrorSystem.getName(decl.constructorName) == '';
      }

      return false;
    }).value as MethodMirror)
        .constructorName;

    return t.newInstance(constructor, row.values ?? <dynamic>[]).reflectee as T;
  }

  Future<T?> find(dynamic id) async {
    Results results = await orm.select('* from $table where id = ?', params: [id as Object]).execute();

    if (results.length == 1) {
      return _produceFrom(results.first);
    }
  }
}

@immutable
abstract class Entity {
  final int id;

  Entity(this.id);
}

class Person extends Entity {
  final String firstname;
  final String lastname;
  final int age;

  Person(int id, this.firstname, this.lastname, this.age) : super(id);
}

void main() async {
  final LoggerService loggerService = LoggerService()..init();
  final Logger logger = loggerService.general;

  Orm o = Orm(ConnectionSettings(
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: 'test',
    db: 'test',
  ));

  Repository<Person> repository = Repository<Person>(orm: o, table: 'person');

  await o.connect();

  Person? person = await repository.find('1');

  if (person != null) {
    logger.warning('Hello ${person.firstname} ${person.lastname} you are ${person.age} years old!');
  } else {
    logger.severe('Not found');
  }

  o.close();
}
