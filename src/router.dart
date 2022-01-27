import 'dart:mirrors';

import 'package:meta/meta.dart';

import 'http.dart';

@immutable
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

@immutable
class RouteCall {
  final Route route;
  final Response Function(Map<String, dynamic>) call;

  RouteCall({required this.route, required this.call});
}

@immutable
class BadlyFormedRouteException implements Exception {
  final String? _message;

  BadlyFormedRouteException([this._message]);

  @override
  String toString() => _message ?? 'Badly formed route';
}

@immutable
class UnknownRoute implements Exception {
  final String? _message;

  UnknownRoute([this._message]);

  @override
  String toString() => _message ?? 'Unknown route';
}

abstract class Hook {
  String? onDispatch(Request request, Route matchedRoute) {}

  void onResponse(Request request, Response response) {}
}

@immutable
class Router {
  final Map<String, Route> _routes = {};
  final Map<Route, RouteCall> _registry = {};
  final Set<Hook> _hooks = {};

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
        if (i >= path.length ||
            (path[i] != routeSegments[i] && routeArgPattern.allMatches(routeSegments[i]).length != 1)) {
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
            'router': this,
          },
        );

        Response? response;

        for (Hook hook in _hooks) {
          String? redirect = hook.onDispatch(request, entry.key);

          if (redirect != null) {
            if (_registry[redirect] != null) {
              response = _registry[redirect]!.call(parameters);
            } else {
              throw UnknownRoute('Unknown route `$redirect`');
            }
          }
        }

        response = response ?? entry.value.call(parameters);

        for (Hook hook in _hooks) {
          hook.onResponse(request, response);
        }

        return response;
      }
    }

    // 404
    return Response.html('Route not found', statusCode: 404);
  }

  void registerHook(Hook hook) => _hooks.add(hook);

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
    _registry[route] = RouteCall(
      route: route,
      call: (final Map<String, dynamic> parameters) => controller.invoke(
        method.simpleName,
        <dynamic>[],
        <Symbol, dynamic>{
          for (ParameterMirror parameter in method.parameters)
            parameter.simpleName: parameters[MirrorSystem.getName(parameter.simpleName)],
        },
      ).reflectee as Response,
    );

    _routes[route.name] = route;

    print("Route `${route.name}` registered as ${route.path}");
  }

  Response redirectToRoute(String name) {
    Route? destination = _routes[name];

    if (destination != null) {
      return Response.redirect(destination.path);
    } else {
      throw ArgumentError('Route `$name` does not exists');
    }
  }
}
