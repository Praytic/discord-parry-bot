import 'dart:io';

import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:sembast/sembast.dart';

import 'db.dart';

Logger _logger = Logger('operations');

INyxxWebsocket setup() {
  final token = Platform.environment['TOKEN'];
  final bot = NyxxFactory.createNyxxWebsocket(token!,
      GatewayIntents.guildMessageReactions | GatewayIntents.guildMessages)
    ..registerPlugin(Logging()) // Default logging plugin
    ..registerPlugin(
        CliIntegration()) // Cli integration for nyxx allows stopping application via SIGTERM and SIGKILl
    ..registerPlugin(
        IgnoreExceptions()) // Plugin that handles uncaught exceptions that may occur
    ..connect().whenComplete(() => _logger.log(
        Level.INFO,
        "Bot initialization is complete. "
        "Discord token: ${_hideCreds(token)}"));
  _setupOperations(bot);
  return bot;
}

void _setupOperations(INyxxWebsocket bot) {
  bot.eventsWs.onMessageReceived.listen((event) async {
    if (event.message.content.contains('парируй')) {
      final mentions = await Future.wait(
          event.message.mentions.map((e) async => e.getOrDownload()));
      final author = await event.message.member?.user.getOrDownload();
      if (author != null) {
        mentions.map((e) => e.id).where((e) => e != author.id).forEach(
            (e) async =>
                challenges.record(author.id.id).put(db, [e.id], merge: true));
        _logger.log(Level.FINE,
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
            _logger.log(
                Level.FINE,
                "${messageAuthor.username} parried ${reactionAuthor.username}'s "
                "challenge");
          }
        });
      }
    }
  });
}

String? _hideCreds(String? creds) =>
    creds?.replaceRange(4, creds.length - 4, '*' * (creds.length - 8));
