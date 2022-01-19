import 'package:http/http.dart';

import 'dom.dart';
import 'router.dart';
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
            method: 'post',
            children: [
              label(
                $for: 'name',
                children: [text('What\'s your name?')],
              ),
              input(
                type: 'text',
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
  Response hello({required Request request}) => Response(
        MyForm().render(),
        200,
        headers: <String, String>{
          'content-type': 'text/html; charset=utf-8',
        },
      );

  @Route(
    name: 'hello.answer',
    path: '/hello',
    methods: {'POST'},
  )
  Response answer({required Request request}) => Response(
        MyView(request.bodyFields['name'] ?? 'Unknown').render(),
        200,
        headers: <String, String>{
          'content-type': 'text/html; charset=utf-8',
        },
      );
}

void main() async {
  final Router router = Router()..register(MyController());

  Server(router: router).run();
}
