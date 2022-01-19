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

typedef RouteCall = Response Function(Request, Map<String, dynamic>);

class BadlyFormedRouteException implements Exception {
  final String? _message;

  BadlyFormedRouteException([this._message]);

  @override
  String toString() => _message ?? 'Badly formed route';
}

class Router {
  // TODO: should be a tree based on path segments
  final Map<Route, RouteCall> _registry = {};

  static final RegExp routeArgPattern = RegExp('{([a-zA-Z0-9_]+)}');

  Response route(Request request) {
    String method = request.method;
    List<String> path = request.url.pathSegments;

    // Search for a matching route
    for (MapEntry<Route, RouteCall> entry in _registry.entries) {
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
        Map<String, dynamic> parameters = <String, dynamic>{};

        // Extract route parameters
        for (int i = 0; i < routeSegments.length; i++) {
          if (routeArgPattern.allMatches(routeSegments[i]).length == 1) {
            // TODO: convert value to expected type (could be String, int or double)
            parameters[routeArgPattern.firstMatch(routeSegments[i])!.group(1)!] = path[i];
          }
        }

        // We do that here so a parameter named 'request' does not shadow the [Request] argument
        parameters.addAll(
          <String, dynamic>{
            'request': request,
          },
        );

        return entry.value(request, parameters);
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

    // Get route placeholders
    List<Match> routeArgMatches = routeArgPattern.allMatches(route.path).toList(growable: false);

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
    _registry[route] = (final Request request, final Map<String, dynamic> parameters) => controller.invoke(
          method.simpleName,
          <dynamic>[],
          <Symbol, dynamic>{
            for (ParameterMirror parameter in method.parameters)
              parameter.simpleName: parameters[MirrorSystem.getName(parameter.simpleName)],
          },
        ).reflectee as Response;
  }
}
