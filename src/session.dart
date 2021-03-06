import 'package:meta/meta.dart';
import 'package:darty_json/darty_json.dart';
import 'package:mysql1/mysql1.dart';
import 'package:uuid/uuid.dart';

import 'http.dart';
import 'injection.dart';
import 'logger.dart';
import 'orm/orm.dart';
import 'router.dart';

class Session {
  final String id;
  final DateTime createdAt;
  final DateTime expiresAt;
  final JsonPayload data;

  Session({
    String? id,
    DateTime? createdAt,
    DateTime? expiresAt,
    JsonPayload? data,
  })  : id = id ?? Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        expiresAt = DateTime.now().add(Duration(minutes: 10)),
        data = data ?? JsonPayload();

  Json operator [](String key) => data[key];
  void operator []=(String key, dynamic value) => data[key] = value;

  bool get isExpired => expiresAt.isBefore(DateTime.now());

  int get size => data.toString().codeUnits.length;
}

typedef SessionIdRetriever = Future<String?> Function(Request);

Future<String?> retrieveFromCookie(Request request) async {
  Map<String, String> cookie = {};
  request.headers['cookie']?.split(';').forEach((String kv) => cookie[kv.split('=')[0]] = kv.split('=')[1]);

  return cookie['bullseye_session_id'];
}

class SessionSizeLimitExceeded implements Exception {
  final String? _message;

  SessionSizeLimitExceeded([this._message]);

  @override
  String toString() => _message ?? 'Session size exceeded';
}

abstract class SessionStorage {
  final SessionIdRetriever retriever;
  final Map<String, Session> _sessionCache = {};
  final int? sizeLimit;

  SessionStorage(this.retriever, {this.sizeLimit});

  @mustCallSuper
  Future<void> write(Session session) async {
    if (sizeLimit != null && session.size > sizeLimit!) {
      throw SessionSizeLimitExceeded('Session size exceeded (limit is $sizeLimit bytes)');
    }
  }

  Future<Session?> read(String sessionId);

  Future<Session> load(Request request) async {
    String? sessionId = await retriever(request);

    Session? session;
    if (sessionId != null) {
      session = _sessionCache[sessionId] ?? await read(sessionId);
      if (session != null) _sessionCache[sessionId] = session;
    }

    if (sessionId == null || session == null || session.isExpired) {
      if (session?.isExpired ?? false) {
        await delete(session!.id);
      }

      // Create one
      session = Session();

      await write(session);

      _sessionCache[session.id] = session;

      sessionId = session.id;
    }

    return _sessionCache[sessionId]!;
  }

  Future<void> delete(String sessionId);
}

class SessionHook extends RoutingHook with Logged {
  @override
  Future<String?> onDispatch(Request request, Route matchedRoute) async {
    SessionStorage? sessionStorage = DependencyRegistry.current.get<SessionStorage>();

    request.attributes.session = await sessionStorage.load(request);
  }

  @override
  Future<void> onResponse(Request request, Response response) async {
    SessionStorage? sessionStorage = DependencyRegistry.current.get<SessionStorage>();
    Session? session = request.attributes.session;

    if (session != null) {
      await sessionStorage.write(session);
      String? setCookie = response.headers['set-cookie'];
      response.headers['set-cookie'] = '${setCookie != null ? '$setCookie;' : ''}bullseye_session_id=${session.id}';
    }
  }
}

class DatabaseSessionStorage extends SessionStorage with Logged {
  DatabaseSessionStorage({
    SessionIdRetriever retriever = retrieveFromCookie,
  }) : super(retriever);

  @override
  Future<void> delete(String sessionId) async {
    final orm = DependencyRegistry.current.get<MySqlOrm>();

    bool deleted =
        (await orm.delete('session', conditions: ['id = ?'], params: [sessionId]).execute()).affectedRows == 1;

    if (deleted) {
      logger.fine('Session `$sessionId` deleted');
    }
  }

  @override
  Future<Session?> read(String sessionId) async {
    final orm = DependencyRegistry.current.get<MySqlOrm>();

    Results results = await orm.select('id, created_at, expires_at, data from session').execute();

    if (results.length == 1) {
      ResultRow row = results.first;

      logger.fine('Session `$sessionId` retrieved');

      return Session(
        id: row['id'] as String,
        createdAt: row['created_at'] as DateTime,
        expiresAt: row['expires_at'] as DateTime,
        data: JsonPayload.fromString((row['data'] as String?)?.toString() ?? '{}'),
      );
    }
  }

  @override
  Future<void> write(Session session) async {
    super.write(session);

    final orm = DependencyRegistry.current.get<MySqlOrm>();

    await orm.execute(
      'INSERT INTO session (id, created_at, expires_at, data) VALUES (?, ?, ?, ?)'
      '  ON DUPLICATE KEY UPDATE created_at = ?, expires_at = ?, data = ?',
      params: [
        session.id,
        session.createdAt.mysqlTimeStamp,
        session.expiresAt.mysqlTimeStamp,
        session.data.toString(),
        session.createdAt.mysqlTimeStamp,
        session.expiresAt.mysqlTimeStamp,
        session.data.toString(),
      ],
    );

    logger.fine('Session `${session.id}` updated');
  }
}

extension MySqlDateTime on DateTime {
  String get mysqlTimeStamp => '$year-$month-$hour $hour:$minute:$second';
}
