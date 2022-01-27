import 'dart:io';

import 'package:darty_json/darty_json.dart';
import 'package:http/http.dart' as http;

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

  Response.redirect(
    String targetUrl, {
    this.statusCode = 302,
    Map<String, String> headers = const {},
  })  : body = '',
        headers = Map.from(headers)
          ..addAll({'location': targetUrl})
          ..removeWhere((key, value) => key.toLowerCase() == 'cache-control' && statusCode == 301) {
    if (![201, 301, 302, 303, 307, 308].contains(statusCode)) {
      throw ArgumentError('Status code is not a redirect');
    }
  }

  void apply(HttpResponse target) {
    target.statusCode = statusCode;
    headers.forEach(
      (key, value) => target.headers.set(key, value),
    );

    target.write(body);
  }
}
