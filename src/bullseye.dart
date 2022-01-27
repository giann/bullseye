import 'dart:math';

import 'dom.dart';
import 'router.dart';
import 'http.dart';
import 'server.dart';
import 'template.dart';

class MyForm extends Template {
  @override
  String render() => div(
        attributes: <NodeAttribute>{
          attr('class', 'yolo'),
        },
        children: [
          h1(
            children: [text('Hello there!')],
          ),
          form(
            action: '/hello',
            children: [
              label(
                $for: 'name',
                children: [text('What\'s your name?')],
              ),
              input(
                id: 'name',
                name: 'name',
              )
            ],
          )
        ],
      ).render();
}

class MyView extends Template {
  String name;

  MyView(this.name);

  @override
  String render() => div(
        children: [
          h1(
            children: [
              text('Hello $name'),
            ],
          ),
        ],
      ).render();
}

class MyController {
  @Route(
    name: 'hello',
    path: '/hello',
    methods: {'GET'},
  )
  Response hello({required Request request}) => Response.html(MyForm().render());

  @Route(
    name: 'hello.answer',
    path: '/hello',
    methods: {'POST'},
  )
  Response answer({
    required Router router,
    required Request request,
  }) {
    String name = request.bodyFields['name'] ?? 'Unknown';

    if (name == "bye") {
      return router.redirectToRoute('bye');
    }

    return Response.html(
      MyView(
        request.bodyFields['name'] ?? 'Unknown',
      ).render(),
    );
  }

  @Route(
    name: 'bye',
    path: '/bye',
    methods: {'GET'},
  )
  Response bye({required Request request}) => Response.html(
        h1(
          children: [
            text('Goodbye'),
          ],
        ).render(),
      );
}

class LoggingHook extends Hook {
  @override
  String? onDispatch(Request request, Route matchedRoute) {
    print("Matched [${request.method.toUpperCase()}] ${matchedRoute.name}");

    return null;
  }

  @override
  void onResponse(Request request, Response response) {
    print("Will respond:\n${response.body.substring(0, min(150, response.body.length))}...");
  }
}

void main() async {
  final Router router = Router()
    ..register(MyController())
    ..registerHook(LoggingHook());

  Server(router: router).run();
}
