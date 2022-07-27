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
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

File outputFile = File('application.log');
Logger logger = Logger('main');

void main() async {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((LogRecord rec) async {
    await outputFile.writeAsString(
        '[${rec.time}] [${rec.level}] [${rec.loggerName}] ${rec.message}\n',
        mode: FileMode.append);
  });

  final db = await databaseFactoryIo
      .openDatabase('.dart_tool/sembast/parry-bot.db')
      .whenComplete(() => logger.info("Database connection has been opened."));
  final challenges = StoreRef<int, List<Object?>>('challenges');
  final scores = StoreRef<int, int>('scores');

  final token = Platform.environment['TOKEN'];
  final bot = NyxxFactory.createNyxxWebsocket(token!,
      GatewayIntents.guildMessageReactions | GatewayIntents.guildMessages)
    ..registerPlugin(Logging()) // Default logging plugin
    ..registerPlugin(
        CliIntegration()) // Cli integration for nyxx allows stopping application via SIGTERM and SIGKILl
    ..registerPlugin(
        IgnoreExceptions()) // Plugin that handles uncaught exceptions that may occur
    ..connect().whenComplete(() => logger.log(
        Level.INFO,
        "Bot initialization is complete. "
        "Discord token: ${hideCreds(token)}"));

  // Listen for message events
  bot.eventsWs.onMessageReceived.listen((event) async {
    if (event.message.content.contains('парируй')) {
      final mentions = await Future.wait(
          event.message.mentions.map((e) async => e.getOrDownload()));
      final author = await event.message.member?.user.getOrDownload();
      if (author != null) {
        mentions.map((e) => e.id).where((e) => e != author.id).forEach(
            (e) async =>
                challenges.record(author.id.id).put(db, [e.id], merge: true));
        logger.log(Level.FINE,
            "${author.username} challenged ${mentions.map((e) => e.username).where((e) => e != author.username)}");
      }
    }
  });

  bot.eventsWs.onSelfMention.listen((event) async {
    final user = await event.message.member?.user.getOrDownload();
    final username = user?.username;
    final score = await scores.record(user!.id.id).get(db) ?? 0;
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
        await db.transaction((txn) async {
          final parriers =
              await challenges.record(reactionAuthor.id.id).get(txn);
          final mutableParriers = parriers?.toList();
          final parried = mutableParriers?.remove(messageAuthor.id.id) ?? false;
          if (parried) {
            await challenges
                .record(reactionAuthor.id.id)
                .put(txn, mutableParriers!);
            final score =
                await scores.record(messageAuthor.id.id).get(txn) ?? 0;
            await scores.record(messageAuthor.id.id).put(txn, score + 1);
            // await message.deleteUserReaction(event.emoji, message);
            logger.log(
                Level.FINE,
                "${messageAuthor.username} parried ${reactionAuthor.username}'s "
                "challenge");
          }
        });
      }
    }
  });

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 80)
      .whenComplete(() => logger.info("Web server is ready to serve requests "
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
      logger.log(Level.SEVERE, exception.toString());
      response.addError(exception, stackTrace);
    } finally {
      response
        ..flush()
        ..close();
      logger.log(Level.INFO, "Web server has been unbound.");
    }
  });

  await db
      .close()
      .whenComplete(() => logger.info("Database connection has been closed."));
}

String? hideCreds(String? creds) =>
    creds?.replaceRange(4, creds.length - 4, '*' * (creds.length - 8));
