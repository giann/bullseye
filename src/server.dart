import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'logger.dart';
import 'router.dart';
import 'http.dart';

class Server with Logged {
  Router router;

  Server({required this.router});

  Future<void> run() async {
    HttpServer server = await HttpServer.bind(InternetAddress.anyIPv6, 8080);

    logger.info("Listening on :8080...");

    await server.forEach((HttpRequest httpRequest) async {
      try {
        logger.info("Received [${httpRequest.method.toUpperCase()}] ${httpRequest.uri.toString()}");

        http.Request request = await _httpToIoRequest(httpRequest);

        (await router.route(Request(request))).apply(httpRequest.response);

        httpRequest.response.close();
      } catch (e) {
        logger.severe('Error occured while processing request: $e');
        if (e is Error) {
          e.stackTrace?.toString().split('\n').forEach((line) => logger.severe(line));
        }
        httpRequest.response.statusCode = 500;
        httpRequest.response.write('Error occured while processing request: $e');
      }
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
