import 'dart:collection';

import 'dom.dart' as d;
import 'http.dart';

import 'package:meta/meta.dart';

import 'template.dart';

@immutable
class Validator<T> {
  final String name;
  final bool Function(T?) validate;

  const Validator(this.name, this.validate);

  factory Validator.required() => Validator(
        'required',
        (T? value) => value != null,
      );

  factory Validator.minLength(int length) => Validator<T>(
        'minLength',
        (T? value) {
          if (value is! String) return false;

          return value.length > length;
        },
      );

  factory Validator.maxLength(int length) => Validator<T>(
        'maxLength',
        (T? value) {
          if (value is! String) return false;

          return value.length < length;
        },
      );
}

@immutable
class InvalidFieldValue implements Exception {
  final String? _message;
  final String validator;

  InvalidFieldValue(this.validator, [this._message]);

  @override
  String toString() => _message ?? 'Field does not respect $validator';
}

abstract class Field<T> implements Template {
  String name;
  T? Function(Request)? parser;
  T? defaultValue;
  List<Validator<T>>? validators;
  T? value;
  String? label;

  Field({
    required this.name,
    this.parser,
    this.defaultValue,
    this.label,
    this.validators,
  });

  void populate(Request request) {
    if (!['GET', 'POST', 'PUT'].contains(request.method)) return;

    Map<String, String> raw = request.method == 'GET' ? request.url.queryParameters : request.bodyFields;

    T? value = (parser != null ? parser!(request) : raw[name] as T?) ?? defaultValue;

    for (Validator<T> validator in validators ?? []) {
      if (!validator.validate(value)) {
        throw InvalidFieldValue(name, 'Field `$name` does not respect `${validator.name}` validator');
      }
    }

    this.value = value;
  }

  List<d.Node> build() => [
        if (label != null) d.label($for: name, label: label!),
      ];

  @override
  String render() => build().map<String>((d.Node node) => node.render()).join();
}

class TextField extends Field<String> {
  TextField({
    required String name,
    String? Function(Request)? builder,
    String? defaultValue,
    String? label,
    List<Validator<String>> validators = const <Validator<String>>[],
  }) : super(
          name: name,
          parser: builder,
          defaultValue: defaultValue,
          label: label,
          validators: validators,
        );

  @override
  List<d.Node> build() => [
        ...super.build(),
        d.input(
          name: name,
          attributes: {
            if (value != null || defaultValue != null) d.attr('value', value ?? defaultValue ?? ''),
          },
        )
      ];
}

class Form implements Template {
  String name;
  String action;
  LinkedHashMap<String, Field> fields;
  Map<String, List<InvalidFieldValue>> errors = {};

  Form({
    required this.name,
    required this.action,
    required this.fields,
  });

  Field? operator [](String name) => fields[name];
  void operator []=(String name, Field field) => fields[name] = field;

  void populate(Request request) {
    errors = {};

    fields.forEach((String name, Field field) {
      try {
        field.populate(request);
      } on InvalidFieldValue catch (e) {
        errors[field.name] = (errors[field.name] ?? [])..add(e);
      }
    });
  }

  d.Node build() => d.form(
        action: action,
        children: [
          for (MapEntry<String, Field> entry in fields.entries) ...[
            ...entry.value.build(),
            if (errors[entry.value.name]?.isNotEmpty ?? false)
              d.div(
                children: [
                  d.text(
                    errors[entry.value.name]!.first.toString(),
                  ),
                ],
              ),
          ],
        ],
      );

  @override
  String render() => build().render();

  bool get isValid => errors.isEmpty;
}
