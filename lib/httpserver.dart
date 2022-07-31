import 'dart:io';

import 'package:logging/logging.dart';
import 'package:sembast/sembast.dart';

import 'db.dart';

Logger _logger = Logger('httpserver');

Future<void> setup() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 80)
      .whenComplete(() => _logger.info("Web server is ready to serve requests "
      "on port 80."));
  await server.forEach((HttpRequest request) {
    final response = request.response
      ..headers.set('Access-Control-Allow-Origin', '*')
      ..headers
          .set('Access-Control-Allow-Methods', 'POST,GET,DELETE,PUT,OPTIONS');
    try {
      switch (request.method) {
        case 'GET':
          switch (request.uri.path) {
            case '/duelmap':
              challenges.find(db).then((value) => response.write('${value}'));
              break;
            case '/scores':
              scores.find(db).then((value) => response.write('${value}'));
              break;
            default:
              throw Exception('URI path [${request.uri.path}] '
                  'is not supported.');
          }
          break;
        default:
          throw Exception('HTTP method [${request.method}] is not supported.');
      }
    } catch (exception, stackTrace) {
      _logger.log(Level.SEVERE, exception.toString());
      response.addError(exception, stackTrace);
    } finally {
      response
        ..flush()
        ..close();
      _logger.log(Level.INFO, "Web server has been unbound.");
    }
  });
}
