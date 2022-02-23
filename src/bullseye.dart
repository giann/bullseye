import 'dart:collection';
import 'dart:math';

import 'package:mysql1/mysql1.dart' as mysql;

import 'dom.dart';
import 'env.dart';
import 'form.dart';
import 'injection.dart';
import 'logger.dart';
import 'orm/orm.dart';
import 'router.dart';
import 'http.dart';
import 'server.dart';
import 'session.dart';
import 'template.dart';

class MyForm implements Template {
  Form myForm;
  Session? session;

  MyForm(this.myForm, this.session);

  @override
  String render() => div(
        attributes: <NodeAttribute>{
          attr('class', 'yolo'),
        },
        children: [
          h1('Hello there!'),
          myForm.build(),
          if (session != null)
            p(
              children: [
                text('User ${session!.id} visited this page ${session!['count'].integerValue}'),
              ],
            )
        ],
      ).render();
}

class MyView implements Template {
  String name;

  MyView(this.name);

  @override
  String render() => div(
        children: [
          h1('Hello $name'),
        ],
      ).render();
}

class MyController {
  Form myForm = Form(
    name: 'greetings',
    action: '/hello',
    fields: LinkedHashMap<String, Field>.from(
      <String, Field>{
        'name': TextField(
          name: 'name',
          label: 'Wath\'s your name',
          validators: [
            Validator<String>.minLength(5),
            Validator<String>.required(),
          ],
        ),
      },
    ),
  );

  @Route(
    name: 'hello',
    path: '/hello',
    methods: {'GET', 'POST'},
  )
  Response hello({
    required Router router,
    required Request request,
    required LoggerService loggerService,
    required Session session,
  }) {
    loggerService.general.warning('AYA!');

    session['count'] = session['count'].integerValue + 1;

    myForm.populate(request);

    if (request.method == 'POST' && myForm.isValid) {
      String name = myForm['name']?.value as String? ?? 'Unknown';

      if (name == "bye") {
        return router.redirectToRoute('bye');
      }

      return Response.html(
        MyView(name).render(),
      );
    }

    return Response.html(
      MyForm(myForm, session).render(),
    );
  }

  @Route(
    name: 'bye',
    path: '/bye',
    methods: {'GET'},
  )
  Response bye({required Request request}) => Response.html(
        h1('Goodbye').render(),
      );

  @Route(
    name: 'login',
    path: '/login/{id}',
    methods: {'GET'},
  )
  Response login({
    required Request request,
    required String id,
  }) =>
      Response.html(
        h1('You\'re logged in $id!').render(),
      );
}

class LoggingHook extends Hook with Logged {
  @override
  Future<String?> onDispatch(Request request, Route matchedRoute) async {
    logger.info("Matched [${request.method.toUpperCase()}] ${matchedRoute.name}");

    return null;
  }

  @override
  Future<void> onResponse(Request request, Response response) async {
    logger.info("Will respond:\n${response.body.substring(0, min(150, response.body.length))}...");
  }
}

void main() async {
  MySqlOrm orm = MySqlOrm(
    mysql.ConnectionSettings(
      host: 'localhost',
      port: 3306,
      user: 'root',
      password: 'test',
      db: 'test',
    ),
  );

  await orm.connect();

  DependencyRegistry di = DependencyRegistry.current
    ..put<Env>(Env()..load())
    // TODO: should probably instanciate an on demand orm connection on a per request basis
    ..put<MySqlOrm>(orm)
    ..put<SessionStorage>(DatabaseSessionStorage(orm: orm))
    ..put<LoggerService>(LoggerService()..init())
    ..put<Router>(
      Router()
        ..register(MyController())
        ..registerHook(SessionHook())
        ..registerHook(LoggingHook()),
    );

  await Server(router: di.get<Router>()!).run();

  orm.close();
}
