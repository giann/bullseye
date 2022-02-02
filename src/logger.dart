import 'dart:mirrors';

import 'package:ansicolor/ansicolor.dart';
import 'package:logging/logging.dart';

class LoggerService {
  final Logger general = Logger('general');

  void init() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      AnsiPen pen = AnsiPen();

      if (record.level.value <= Level.CONFIG.value) {
        pen.gray(level: 0.5);
      } else if (record.level.value == Level.WARNING.value) {
        pen.yellow();
      } else if (record.level.value == Level.SEVERE.value) {
        pen.red();
      } else if (record.level.value == Level.SHOUT.value) {
        pen.red(bg: true);
      }

      print(
        pen(
          '${record.time.hour}:${record.time.minute}:${record.time.second}:${record.time.millisecond} [${record.loggerName.toUpperCase()}] ${record.message}',
        ),
      );
    });
  }
}

mixin Logged {
  Logger? _logger;

  Logger get logger {
    if (_logger == null) {
      InstanceMirror instanceMirror = reflect(this);
      ClassMirror classMirror = instanceMirror.type;

      String key = MirrorSystem.getName(classMirror.simpleName);

      _logger = Logger(key);
    }

    return _logger!;
  }
}
