import 'package:meta/meta.dart';

@immutable
class ConfigurationValue<T> {
  final T value;

  ConfigurationValue(this.value);
}

@immutable
class ConfigurationKey {
  final String domain;
  final String key;

  const ConfigurationKey(this.domain, this.key);

  @override
  bool operator ==(dynamic other) => other is ConfigurationKey && domain == other.domain && key == other.key;

  @override
  int get hashCode => '$domain.$key'.hashCode;
}

class Configuration {
  final Map<ConfigurationKey, ConfigurationValue> _config = {};

  Configuration();

  void set<T>(String domain, String key, T value) =>
      _config[ConfigurationKey(domain, key)] = ConfigurationValue<T>(value);

  T get<T>(String domain, String key) {
    ConfigurationKey confKey = ConfigurationKey(domain, key);
    ConfigurationValue? value = _config[confKey];

    if (value == null) {
      throw ConfigurationNotFound('No configuration value found for ${confKey.domain}.${confKey.key}');
    }

    if (value is! ConfigurationValue<T>) {
      throw BadConfigurationValueType('Configuration value expected to be $T, found ${value.value.runtimeType}');
    }

    return value.value;
  }
}

class ConfigurationNotFound implements Exception {
  final String? _message;

  ConfigurationNotFound([this._message]);

  @override
  String toString() => _message ?? 'No configuration value found';
}

class BadConfigurationValueType implements Exception {
  final String? _message;

  BadConfigurationValueType([this._message]);

  @override
  String toString() => _message ?? 'Configuration value type is not of expected type';
}
