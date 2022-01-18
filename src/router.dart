import 'package:http/http.dart';
import 'dart:mirrors';

class Route {
  final String name;
  final String path;
  final Set<String> methods;

  const Route({
    required this.name,
    required this.path,
    this.methods = const {},
  });

  bool match(Uri url) => false;

  // So that a Map<Route, dynamic> will no tolerate two instances of Route with the same name
  @override
  bool operator ==(Object other) => other is Route && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

typedef RouteCall = Response Function(Map<String, dynamic>);

class BadlyFormedRouteException implements Exception {
  final String? _message;

  BadlyFormedRouteException([this._message]);

  @override
  String toString() => _message ?? 'Badly formed route';
}

class Router {
  // TODO: should be a tree based on path segments
  Map<Route, RouteCall> registry = {};

  static final RegExp routeArgPattern = RegExp('{([a-zA-Z0-9_]+)}');

  Response route(Request request) {
    String method = request.method;
    List<String> path = request.url.pathSegments;

    // Search for a matching route
    for (MapEntry<Route, RouteCall> entry in registry.entries) {
      if (!entry.key.methods.contains(method.toUpperCase())) {
        continue;
      }

      List<String> routeSegments = entry.key.path.substring(1).split('/');

      bool matches = true;
      for (int i = 0; i < routeSegments.length; i++) {
        if (path[i] != routeSegments[i] && routeArgPattern.allMatches(routeSegments[i]).length != 1) {
          matches = false;
          break;
        }
      }

      // We matched!
      if (matches) {
        // Extract route parameters
        Map<String, String> parameters = {};

        for (int i = 0; i < routeSegments.length; i++) {
          if (routeArgPattern.allMatches(routeSegments[i]).length == 1) {
            parameters[routeArgPattern.firstMatch(routeSegments[i])!.group(1)!] = path[i];
          }
        }

        return entry.value(parameters);
      }
    }

    // 404
    return Response('Route not found', 404);
  }

  void register(dynamic controller) {
    InstanceMirror instanceMirror = reflect(controller);
    ClassMirror controllerMirror = instanceMirror.type;

    // Search for [Route] annotated methods

    // Iterate through instance methods
    controllerMirror.instanceMembers.forEach(
      (Symbol key, MethodMirror method) {
        // Filter out private and operator overloads
        if (!method.isPrivate && !method.isOperator) {
          // Search for a [Route] route
          for (InstanceMirror metadata in method.metadata) {
            dynamic annotation = metadata.reflectee;

            // Is it annotated with [Route]
            if (annotation is Route) {
              _methodMatchesRoute(method, annotation);

              _registerRoute(instanceMirror, method, annotation);
            }
          }
        }
      },
    );
  }

  void _methodMatchesRoute(MethodMirror method, Route route) {
    if (method.returnType.reflectedType != Response) {
      throw BadlyFormedRouteException('Route method should return a `Response`');
    }

    // Method arguments have simple types
    for (ParameterMirror parameter in method.parameters) {
      if (![String, int, double].contains(parameter.type.reflectedType)) {
        throw BadlyFormedRouteException('Route method\'s arguments must be of type: String, int or double');
      }
    }

    // Get route placeholders
    List<Match> routeArgMatches = routeArgPattern.allMatches(route.path).toList(growable: false);

    if (routeArgMatches.length != method.parameters.length) {
      throw BadlyFormedRouteException('Route method\'s arguments count does not match path parameters count');
    }

    for (Match routeArg in routeArgMatches) {
      bool foundMatch = false;
      for (ParameterMirror parameter in method.parameters) {
        if (MirrorSystem.getName(parameter.simpleName) == routeArg.group(1)) {
          foundMatch = true;
          break;
        }
      }

      if (!foundMatch) {
        throw BadlyFormedRouteException('Route method does not have an argument named `${routeArg.group(1)}`');
      }
    }
  }

  void _registerRoute(InstanceMirror controller, MethodMirror method, Route route) {
    // Register a function that will inject parameters as method arguments
    // We don't check here if parameters are matching the method arguments, this is done at register time
    registry[route] = (final Map<String, dynamic> parameters) => controller
        .invoke(
          method.simpleName,
          <dynamic>[],
          // ignore: prefer_for_elements_to_map_fromiterable
          Map<Symbol, dynamic>.fromIterable(
            method.parameters,
            key: (dynamic parameter) => (parameter as ParameterMirror).simpleName,
            value: (dynamic parameter) => parameters[MirrorSystem.getName((parameter as ParameterMirror).simpleName)],
          ),
        )
        .reflectee as Response;
  }
}
