import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';
import '../src/router.dart';
import '../src/dom.dart';
import '../src/http.dart';
import 'package:http/http.dart' as http;

class TestController {
  @Route(
    name: 'hello',
    path: '/hello',
    methods: {'GET'},
  )
  Future<Response> bye({required Request request}) async => Response.html(text('hello').render());
}

void main() {
  test(
    'Routes to approriate route',
    () async {
      final Router router = Router()..register(TestController());

      Request request = Request(http.Request('GET', Uri.parse('/hello')));

      Response response = await router.route(request);

      expect(response.statusCode, equals(200));
      expect(response.body, equals('hello'));
    },
  );
}
