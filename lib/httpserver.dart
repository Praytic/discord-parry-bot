import 'dart:io';

import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:sembast/sembast.dart';

import 'bot.dart';
import 'db.dart';

Logger _logger = Logger('HTTP Server');

Future<void> setup(INyxxWebsocket bot) async {
  (await HttpServer.bind(InternetAddress.anyIPv4, 80)
      .whenComplete(() => _logger.info("Web server is ready to serve requests "
          "on port 80.")))
    .listen((HttpRequest request) async {
      final response = request.response
        ..headers.set('Access-Control-Allow-Origin', '*')
        ..headers
            .set('Access-Control-Allow-Methods', 'POST,GET,DELETE,PUT,OPTIONS')
        ..statusCode = HttpStatus.ok;
      try {
        switch (request.method) {
          case 'GET':
            switch (request.uri.path) {
              case '/duelmap':
                await challenges
                    .find(db)
                    .then((value) => response.write('${value}'));
                break;
              case '/guilds':
                response.write(getGuilds(bot));
                break;
              case '/scores':
                await scores
                    .find(db)
                    .then((value) => response.write('${value}'));
                break;
              case '/favicon.ico':
                response.statusCode = HttpStatus.notFound;
                break;
              default:
                if (request.uri.path.startsWith("/channelHistory")) {
                  final id = request.uri.path.split("/").last;
                  response.write(await getChannelHistory(bot, Uri.decodeFull(id)));
                } else if (request.uri.path.startsWith("/guildChannels")) {
                  final id = int.parse(request.uri.path.split("/").last);
                  response.write(getChannels(bot, Snowflake.value(id)));
                } else {
                  throw Exception('URI path [${request.uri.path}] '
                      'is not supported.');
                }
            }
            break;
          default:
            throw Exception(
                'HTTP method [${request.method}] is not supported.');
        }
      } catch (exception, stackTrace) {
        _logger.log(Level.SEVERE, exception.toString());
        response.addError(exception, stackTrace);
      } finally {
        await response.flush();
        await response.close();
      }
    },
        onError: (error) => _logger.severe("Web server has crashed", error),
        onDone: () =>
            _logger.log(Level.INFO, "Web server has processed a request."));
}
