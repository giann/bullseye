import 'dart:io';
import 'dart:typed_data';

import 'package:darty_json/darty_json.dart';
import 'package:http/http.dart' as http;

import 'router.dart';

class Request {
  final http.Request _raw;

  Request(this._raw);

  Uri get url => _raw.url;
  String get method => _raw.method;
  Map<String, String> get bodyFields => _raw.bodyFields;
}

class Response {
  String body;
  int statusCode;
  Map<String, String> headers;

  Response.json(
    Json data, {
    this.statusCode = 200,
    Map<String, String> headers = const {},
  })  : body = data.toString(),
        headers = {}..addAll(
            {
              ...headers,
              ...{'content-type': 'application/json'}
            },
          );

  Response.html(
    String html, {
    this.statusCode = 200,
    Map<String, String> headers = const {},
  })  : body = html,
        headers = {}..addAll(
            {
              ...headers,
              ...{'content-type': 'text/html; charset=utf-8'}
            },
          );

  void apply(HttpResponse target) {
    target.statusCode = statusCode;
    headers.forEach(
      (key, value) => target.headers.set(key, value),
    );

    target.write(body);
  }
}

class Server {
  Router router;

  Server({required this.router});

  void run() async {
    HttpServer server = await HttpServer.bind(InternetAddress.anyIPv6, 8080);

    print("Listening on :8080...");

    await server.forEach((HttpRequest httpRequest) async {
      print("Received [${httpRequest.method.toUpperCase()}] ${httpRequest.uri.toString()}");

      http.Request request = await _httpToIoRequest(httpRequest);

      router.route(Request(request)).apply(httpRequest.response);

      httpRequest.response.close();
    });
  }

  // http:http.dart is way easier to use but does not provide a server, so we have to convert request/responses
  // between the two implementations

  Future<http.Request> _httpToIoRequest(HttpRequest httpRequest) async {
    http.Request request = http.Request(httpRequest.method, httpRequest.uri);
    request.body = await httpRequest.map<String>((Uint8List body) => String.fromCharCodes(body)).join('');
    httpRequest.headers.forEach(
      (String name, List<String> values) => request.headers[name] = values.join(';'),
    );

    return request;
  }
}
