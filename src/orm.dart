import 'package:mysql1/mysql1.dart';

void main() async {
  ConnectionSettings settings = ConnectionSettings(
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: 'test',
    db: 'auth',
  );

  MySqlConnection conn = await MySqlConnection.connect(settings);

  // first query always empty
  // https://github.com/adamlofts/mysql1_dart/issues/106
  await conn.query('select * from client;');
  Results results = await conn.query('select * from client;');

  print('Rows: ${results.affectedRows}');
  for (ResultRow result in results) {
    print(result.values);
  }

  conn.close();
}
