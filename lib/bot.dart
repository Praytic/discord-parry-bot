import 'dart:io';

import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:sembast/sembast.dart';

import 'Battlefield.dart';
import 'db.dart';

Logger _logger = Logger('Bot Operations');
Battlefield battlefield = Battlefield();

INyxxWebsocket setup() {
  final token = Platform.environment['TOKEN'];
  final bot = NyxxFactory.createNyxxWebsocket(token!,
      GatewayIntents.guildMessageReactions | GatewayIntents.guildMessages)
    ..registerPlugin(Logging()) // Default logging plugin
    ..registerPlugin(
        CliIntegration()) // Cli integration for nyxx allows stopping application via SIGTERM and SIGKILl
    ..registerPlugin(
        IgnoreExceptions()) // Plugin that handles uncaught exceptions that may occur
    ..connect().whenComplete(() =>
        _logger.log(
            Level.INFO,
            "Bot initialization is complete. "
                "Discord token: ${_hideCreds(token)}"));
  _setupOperations(bot);
  return bot;
}

void _setupOperations(INyxxWebsocket bot) {
  bot.eventsWs.onMessageReceived.listen((event) async {
    if (battlefield.hasMentionOfChallenge(event.message)) {
      await battlefield.handleChallenge(event.message);
    } else if (await battlefield.isTryingToParry(event.message)) {
      await battlefield.handleParry(
          event.message, event.message.referencedMessage!.message!.author);
    }
  });

  bot.eventsWs.onSelfMention.listen((event) async {
    final user = await event.message.member?.user.getOrDownload();

    final username = user?.username;
    final score = await scores.record(user!.id.id).get(db) ?? 0;
    if (username != null) {
      await event.message.channel.sendMessage(MessageBuilder.embed(
          EmbedBuilder()
            ..description = '$username спарировал $score раз'));
    }
  });

  bot.eventsWs.onMessageReactionAdded.listen((event) async {
    if (event.emoji.encodeForAPI() == '⚔️') {
      final message = await event.channel.fetchMessage(event.messageId);
      final reactionAuthor = await event.user.getOrDownload();
      await battlefield.handleParry(message, reactionAuthor);
    }
  });
}

String? _hideCreds(String? creds) =>
    creds?.replaceRange(4, creds.length - 4, '*' * (creds.length - 8));
