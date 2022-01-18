import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'dom.dart';
import 'router.dart';
import 'template.dart';

@immutable
class MyModel {
  final String name;

  const MyModel(this.name);
}

class MyView extends Template<MyModel> {
  MyView(MyModel context) : super(context);

  @override
  String render() {
    return div(
      attributes: <NodeAttribute>{
        attr('class', 'yolo'),
      },
      children: [
        text('hello my name is: ${context?.name ?? 'Unknown'}'),
      ],
    ).render();
  }
}

class MyController {
  @Route(
    name: 'hello',
    path: '/hello/{name}',
    methods: {'GET'},
  )
  Response hello({required String name}) => Response(MyView(MyModel(name)).render(), 200);
}

void main(List<String> arguments) {
  final router = Router();

  router.register(MyController());

  print(router.route(Request('GET', Uri.parse('/hello/Benoit'))).body);
}
