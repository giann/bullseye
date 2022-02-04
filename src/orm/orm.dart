import 'package:meta/meta.dart';
import 'package:mysql1/mysql1.dart';

import '../logger.dart';

@immutable
class NotConnectedException implements Exception {
  final String? _message;

  NotConnectedException([this._message]);

  @override
  String toString() => _message ?? 'Not connected';
}

class Query {
  final Orm _orm;
  final String _query;
  final List<Object>? _params;
  Results? result;

  Query(this._orm, this._query, this._params);

  Future<Results> execute() async => result = (await _orm.execute(_query, params: _params));
}

class Orm with Logged {
  MySqlConnection? _connection;
  final ConnectionSettings _settings;

  Orm(this._settings);

  Future<void> connect() async {
    _connection = await MySqlConnection.connect(_settings);

    // MySqlConnection.connect does not wait for db to be initialized it seems
    // https://github.com/adamlofts/mysql1_dart/issues/114
    await Future<void>.delayed(Duration(milliseconds: 500));

    logger.fine('Connection to database `${_settings.db}` opened');
  }

  Future<void> close() async {
    await _connection?.close();
    _connection = null;
    logger.fine('Connection to database `${_settings.db}` closed');
  }

  Future<Results> execute(String query, {List<Object>? params}) async {
    if (_connection == null) {
      logger.severe('Not connected to database');
      throw NotConnectedException();
    }

    Results results = await _connection!.query(query, params);

    logger.fine('${results.affectedRows ?? results.length}: `$query`');

    return results;
  }

  Query select(String query, {List<Object>? params}) => Query(this, 'SELECT $query', params);

  Query insert(String table, Map<String, Object> values) {
    String columns = values.entries.map<String>((_) => '?').toList().join(', ');

    return Query(
      this,
      'INSERT INTO $table (${values.keys.join(', ')}) VALUES ($columns)',
      values.values.toList(),
    );
  }

  Query update(
    String table,
    Map<String, Object> values, {
    List<String>? conditions,
    List<Object>? params,
  }) {
    String columns = values.entries.map<String>((entry) => '${entry.key}=?').toList().join(', ');
    String where = conditions != null && conditions.isNotEmpty ? ' WHERE ${conditions.join(' AND ')}' : '';

    return Query(
      this,
      'UPDATE $table SET $columns$where',
      [...values.values, ...(params ?? [])],
    );
  }

  Query delete(
    String table, {
    List<String>? conditions,
    List<Object>? params,
  }) {
    String where = conditions != null && conditions.isNotEmpty ? ' WHERE ${conditions.join(' AND ')}' : '';

    return Query(
      this,
      'DELETE FROM $table $where',
      params,
    );
  }
}