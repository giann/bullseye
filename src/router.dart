import 'dart:mirrors';

import 'package:meta/meta.dart';

import 'http.dart';
import 'injection.dart';
import 'logger.dart';
import 'session.dart';

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
class BadRouteArgumentType implements Exception {
  final String? _message;

  BadRouteArgumentType([this._message]);

  @override
  String toString() => _message ?? 'Route argument is of the wrong type';
}

@immutable
class RouteArgumentNotFound implements Exception {
  final String? _message;

  RouteArgumentNotFound([this._message]);

  @override
  String toString() => _message ?? 'Route argument not found';
}

@immutable
class UnknownRoute implements Exception {
  final String? _message;

  UnknownRoute([this._message]);

  @override
  String toString() => _message ?? 'Unknown route';
}

abstract class Hook {
  Future<String?> onDispatch(Request request, Route matchedRoute);

  Future<void> onResponse(Request request, Response response);
}

class Router with Logged {
  final Map<String, Route> _routes = {};
  final Map<Route, RouteCall> _registry = {};
  final Set<Hook> _hooks = {
    SessionHook(),
  };

  static final RegExp routeArgPattern = RegExp('{([a-zA-Z0-9_]+)}');

  Future<Response> route(Request request) async {
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
          String? redirect = await hook.onDispatch(request, entry.key);

          if (redirect != null) {
            if (_registry[redirect] != null) {
              response = _registry[redirect]!.call(
                parameters
                  ..addAll(
                    <String, dynamic>{
                      'session': request.attributes.session,
                    },
                  ),
              );
            } else {
              throw UnknownRoute('Unknown route `$redirect`');
            }
          }
        }

        response = response ??
            entry.value.call(
              parameters
                ..addAll(
                  <String, dynamic>{
                    'session': request.attributes.session,
                  },
                ),
            );

        for (Hook hook in _hooks) {
          await hook.onResponse(request, response);
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
      call: (final Map<String, dynamic> parameters) {
        Map<Symbol, dynamic> callParameters = <Symbol, dynamic>{};
        for (ParameterMirror parameter in method.parameters) {
          String paramName = MirrorSystem.getName(parameter.simpleName);

          if (parameters.containsKey(paramName)) {
            if (parameter.type.reflectedType == parameters[paramName].runtimeType) {
              callParameters[parameter.simpleName] = parameters[paramName];
            } else {
              throw BadRouteArgumentType(
                'Route `$route` argument `$paramName` should be of type `${parameters[paramName.runtimeType]}`, '
                'expected `${parameter.type.reflectedType}`',
              );
            }
          } else {
            // Try to get it from DI
            dynamic dep = DependencyRegistry.current.getRuntime(parameter.type.reflectedType);

            if (dep != null) {
              callParameters[parameter.simpleName] = dep;
            } else {
              throw RouteArgumentNotFound(
                'Route argument `$paramName` of expected type '
                '`${parameter.type.reflectedType}` was not found',
              );
            }
          }
        }

        return controller
            .invoke(
              method.simpleName,
              <dynamic>[],
              callParameters,
            )
            .reflectee as Response;
      },
    );

    _routes[route.name] = route;

    logger.config("Route `${route.name}` registered as ${route.path}");
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
