import 'dart:collection';
import 'dart:math';

import 'dom.dart';
import 'form.dart';
import 'logger.dart';
import 'router.dart';
import 'http.dart';
import 'server.dart';
import 'template.dart';

class MyForm implements Template {
  Form myForm;

  MyForm(this.myForm);

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
  }) {
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
      MyForm(myForm).render(),
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
  String? onDispatch(Request request, Route matchedRoute) {
    logger.info("Matched [${request.method.toUpperCase()}] ${matchedRoute.name}");

    return null;
  }

  @override
  void onResponse(Request request, Response response) {
    logger.info("Will respond:\n${response.body.substring(0, min(150, response.body.length))}...");
  }
}

void main() async {
  final LoggerService loggerService = LoggerService()..init();

  final Router router = Router()
    ..register(MyController())
    ..registerHook(LoggingHook());

  Server(router: router).run();
}
