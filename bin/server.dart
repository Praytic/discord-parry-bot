// GENERATED CODE - DO NOT MODIFY BY HAND
// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an 'AS IS' BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// ignore_for_file: prefer_single_quotes

import 'dart:async';
import 'dart:io';

import 'package:nyxx/nyxx.dart';
import 'package:logging/logging.dart';

File outputFile = File('application.log');
Logger logger = Logger('main');

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) async {
    await outputFile.writeAsString(
        '[${rec.time}] [${rec.level}] [${rec.loggerName}] ${rec.message}\n',
        mode: FileMode.append);
  });

  final duelmap = <Snowflake, List<Snowflake>>{};
  final scores = <Snowflake, int>{};

  final token = Platform.environment['TOKEN'];
  final bot = NyxxFactory.createNyxxWebsocket(token!,
      GatewayIntents.guildMessageReactions | GatewayIntents.guildMessages)
    ..registerPlugin(Logging()) // Default logging plugin
    ..registerPlugin(
        CliIntegration()) // Cli integration for nyxx allows stopping application via SIGTERM and SIGKILl
    ..registerPlugin(
        IgnoreExceptions()) // Plugin that handles uncaught exceptions that may occur
    ..connect().whenComplete(
        () => logger.log(Level.FINE, "Bot initialization is complete"));

  // Listen for message events
  bot.eventsWs.onMessageReceived.listen((event) async {
    if (event.message.content.contains('парируй')) {
      final mentions = await Future.wait(
          event.message.mentions.map((e) async => e.getOrDownload()));
      final author = await event.message.member?.user.getOrDownload();
      if (author != null) {
        duelmap.putIfAbsent(author.id, () => []);
        final duelists =
            mentions.map((e) => e.id).where((e) => e != author.id).toList();
        duelmap[author.id]?.addAll(duelists);
        logger.log(Level.FINE,
            "${author.username} challenged ${mentions.map((e) => e.username).where((e) => e != author.username)}");
      }
    }
  });

  bot.eventsWs.onSelfMention.listen((event) async {
    final user = await event.message.member?.user.getOrDownload();
    final username = user?.username;
    final score = scores[user] ?? 0;
    if (username != null) {
      await event.message.channel.sendMessage(MessageBuilder.embed(
          EmbedBuilder()..description = '$username спарировал $score раз'));
    }
  });

  bot.eventsWs.onMessageReactionAdded.listen((event) async {
    if (event.emoji.encodeForAPI() == '⚔️') {
      final message = await event.channel.fetchMessage(event.messageId);
      final reactionAuthor = await event.user.getOrDownload();
      final messageAuthor = message.author;
      if (messageAuthor.id != reactionAuthor.id) {
        final parried =
            duelmap[reactionAuthor.id]?.remove(messageAuthor.id) ?? false;
        if (parried) {
          final score = scores.putIfAbsent(messageAuthor.id, () => 0);
          scores[messageAuthor.id] = score + 1;
          // await message.deleteUserReaction(event.emoji, message);
          logger.log(
              Level.FINE,
              "${messageAuthor.username} parried ${reactionAuthor.username}'s "
              "challenge");
        }
      }
    }
  });

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 80);
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
              response.write('$duelmap');
              break;
            case '/scores':
              response.write('$scores');
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
      response.addError(exception, stackTrace);
    } finally {
      response.close();
    }
  });
}
