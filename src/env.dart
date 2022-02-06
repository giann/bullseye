import 'dart:io';
import 'package:dotenv/dotenv.dart' as dot;

class Env {
  Map<String, String> env = {};

  void load() {
    dot.load();
    env = {}
      ..addAll(Platform.environment)
      ..addAll(dot.env);
  }
}

void main() {
  (Env()..load()).env.forEach((key, value) => print('$key=$value'));
}
