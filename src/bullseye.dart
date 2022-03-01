import 'package:meta/meta.dart';
import 'dart:collection';

import 'package:mysql1/mysql1.dart' as mysql;

import 'configuration.dart';
import 'dom.dart';
import 'env.dart';
import 'form.dart';
import 'injection.dart';
import 'logger.dart';
import 'orm/entity.dart';
import 'orm/orm.dart';
import 'router.dart';
import 'http.dart';
import 'server.dart';
import 'session.dart';
import 'template.dart';

@immutable
@entity
class Person {
  @uuid4PrimaryKey
  late final String id;

  @column
  late final String firstname;

  @column
  late final String lastname;

  @Column(columnType: ColumnType.smallint)
  late final int age;
}

class MyFormView implements Template {
  Form myForm;

  MyFormView(this.myForm);

  @override
  String render() => div(
        attributes: <NodeAttribute>{
          attr('class', 'yolo'),
        },
        children: [
          h1('Hello there!'),
          myForm.build(),
        ],
      ).render();
}

class MyView implements Template {
  Person person;

  MyView(this.person);

  @override
  String render() => div(
        children: [
          h1(
            'Hello [${person.id}] '
            '${person.firstname} ${person.lastname} '
            'you are ${person.age} years old!',
          ),
        ],
      ).render();
}

class MyController {
  Form myForm = Form(
    id: 'person',
    action: '/hello',
    fields: LinkedHashMap<String, Field>.from(
      <String, Field>{
        'firstname': TextField(
          name: 'firstname',
          label: 'What\'s your firstname',
          validators: {
            Validator.minLength(5),
            Validator.required<String>(),
          },
        ),
        'lastname': TextField(
          name: 'lastname',
          label: 'What\'s your lastname',
          validators: {
            Validator.minLength(5),
            Validator.required<String>(),
          },
        ),
        'age': NumberField(
          name: 'age',
          label: 'What\'s your age',
          validators: {
            Validator.required<int>(),
            Validator.positive,
          },
        ),
      },
    ),
  );

  @Route(
    name: 'hello',
    path: '/hello',
    methods: {'GET', 'POST'},
  )
  Future<Response> hello({
    required Router router,
    required Request request,
    required LoggerService loggerService,
    required MySqlOrm orm,
    required Session session,
  }) async {
    loggerService.general.warning('AYA!');

    myForm.populate(request);

    Repository<Person> repository = Repository<Person>();

    if (request.method == 'POST' && myForm.isValid) {
      String name = myForm['name']?.getValue<String>() ?? 'Unknown';

      if (name == "bye") {
        return router.redirectToRoute('bye');
      }

      // Persist as a [Person] entity
      Person newPerson = Person();
      newPerson.firstname = myForm['firstname']?.getValue<String>() ?? 'Unknown';
      newPerson.lastname = myForm['lastname']?.getValue<String>() ?? 'Unknown';
      newPerson.age = myForm['age']?.getValue<int>() ?? 0;

      await repository.insert(newPerson);

      // Save id in session
      session['person'] = newPerson.id;

      return Response.html(
        MyView(newPerson).render(),
      );
    } else if (request.method == 'GET' && session['person'].exists()) {
      Person? person = await repository.firstWhere(
        conditions: ['id = ?'],
        params: [session['person'].stringValue],
      );

      if (person != null) {
        return Response.html(MyView(person).render());
      }
    }

    return Response.html(
      MyFormView(myForm).render(),
    );
  }

  @Route(
    name: 'bye',
    path: '/bye',
    methods: {'GET'},
  )
  Future<Response> bye({required Request request}) async => Response.html(h1('Goodbye').render());
}

void main() async {
  DependencyRegistry di = DependencyRegistry.current
    ..put<Env>(instance: Env()..load())
    ..put<Configuration>(
      instance: Configuration()
        ..set<mysql.ConnectionSettings>(
          'orm',
          'connectionSettings',
          mysql.ConnectionSettings(
            host: 'localhost',
            port: 3306,
            user: 'root',
            password: 'test',
            db: 'test',
          ),
        ),
    )
    ..put<MySqlOrm>(builder: () => MySqlOrm())
    ..put<SessionStorage>(instance: DatabaseSessionStorage())
    ..put<LoggerService>(instance: LoggerService())
    ..put<Router>(
      instance: Router()
        ..register(MyController())
        ..registerHook(SessionHook())
        ..registerHook(MySqlOrmHook()),
    );

  await Server(router: di.get<Router>()).run();
}
