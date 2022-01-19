import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';

import 'router.dart';

class Server {
  Router router;

  Server({required this.router});

  void run() async {
    HttpServer server = await HttpServer.bind(InternetAddress.anyIPv6, 8080);

    print("Listening on :8080...");

    await server.forEach((HttpRequest httpRequest) async {
      print("Received [${httpRequest.method.toUpperCase()}] ${httpRequest.uri.toString()}");

      Request request = await _httpToIoRequest(httpRequest);

      _applyRequest(router.route(request), httpRequest);

      httpRequest.response.close();
    });
  }

  // http:http.dart is way easier to use but does not provide a server, so we have to convert request/responses
  // between the two implementations

  Future<Request> _httpToIoRequest(HttpRequest httpRequest) async {
    Request request = Request(httpRequest.method, httpRequest.uri);
    request.body = await httpRequest.map<String>((Uint8List body) => String.fromCharCodes(body)).join('');
    httpRequest.headers.forEach(
      (String name, List<String> values) => request.headers[name] = values.join(';'),
    );

    return request;
  }

  void _applyRequest(Response response, HttpRequest target) {
    target.response.statusCode = response.statusCode;
    response.headers.forEach(
      (key, value) => target.response.headers.set(key, value),
    );

    target.response.write(response.body);
  }
}
